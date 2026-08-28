package com.kelimio.api.offline

import com.fasterxml.jackson.databind.ObjectMapper
import com.kelimio.api.catalog.CatalogRepository
import com.kelimio.api.courseeditor.FullCourseEditorRepository
import com.kelimio.api.identityprofile.AppUser
import com.kelimio.api.identityprofile.CurrentUserService
import com.kelimio.api.web.ForbiddenProblem
import com.kelimio.api.web.NotFoundProblem
import com.kelimio.api.web.UnprocessableProblem
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.http.CacheControl
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.NoSuchKeyException
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import software.amazon.awssdk.services.s3.model.ServerSideEncryption
import software.amazon.awssdk.services.s3.presigner.S3Presigner
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest
import java.security.MessageDigest
import java.time.Clock
import java.time.Duration
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.HexFormat
import java.util.UUID

@RestController
@RequestMapping("/v1/courses/{courseId}/offline-package")
@ConditionalOnProperty(name = ["KELIMIO_OFFLINE_PACKAGES_ENABLED"], havingValue = "true")
@ConditionalOnBean(S3Client::class, S3Presigner::class)
internal class OfflinePackageController(
    private val currentUserService: CurrentUserService,
    private val service: OfflinePackageService,
) {
    @GetMapping
    fun get(
        @AuthenticationPrincipal jwt: Jwt,
        @PathVariable courseId: UUID,
        @RequestParam supportLanguage: String,
    ): ResponseEntity<OfflinePackageResponse> = ResponseEntity.ok()
        .cacheControl(CacheControl.noStore())
        .body(service.get(currentUserService.requireCompleted(jwt), courseId, supportLanguage))
}

internal data class OfflinePackageResponse(
    val courseId: UUID,
    val courseReleaseId: UUID,
    val supportLanguage: String,
    val formatVersion: Int,
    val sha256: String,
    val downloadUrl: String,
    val expiresAt: OffsetDateTime,
)

internal data class OfflinePackagePayload(
    val mode: String = "OFFLINE_SCORELESS",
    val formatVersion: Int = 1,
    val courseReleaseId: UUID,
    val supportLanguage: String,
    val course: Any,
)

@Service
@ConditionalOnProperty(name = ["KELIMIO_OFFLINE_PACKAGES_ENABLED"], havingValue = "true")
@ConditionalOnBean(S3Client::class, S3Presigner::class)
internal class OfflinePackageService(
    private val editorRepository: FullCourseEditorRepository,
    private val catalogRepository: CatalogRepository,
    private val s3: S3Client,
    private val presigner: S3Presigner,
    private val objectMapper: ObjectMapper,
    private val clock: Clock,
    @Value("\${KELIMIO_OFFLINE_PACKAGE_BUCKET}") private val bucket: String,
    @Value("\${KELIMIO_KMS_KEY_ARN:}") private val kmsKeyArn: String,
) {
    @Transactional(readOnly = true)
    fun get(user: AppUser, courseId: UUID, supportLanguage: String): OfflinePackageResponse {
        val course = editorRepository.publishedCourseState(courseId) ?: throw NotFoundProblem("Course was not found.")
        if (!catalogRepository.hasActiveEnrollment(courseId, user.id)) {
            throw ForbiddenProblem("Download requires an active course enrollment.")
        }
        if (supportLanguage !in course.supportLanguages) {
            throw UnprocessableProblem("The course does not support the requested support language.")
        }
        val payload = OfflinePackagePayload(
            courseReleaseId = course.activeReleaseId,
            supportLanguage = supportLanguage,
            course = editorRepository.document(course),
        )
        val bytes = objectMapper.writeValueAsBytes(payload)
        val sha256 = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes))
        val key = "releases/${course.activeReleaseId}/$supportLanguage/v1/$sha256.json"
        ensureObject(key, sha256, bytes)
        val duration = Duration.ofMinutes(15)
        val signed = presigner.presignGetObject(
            GetObjectPresignRequest.builder().signatureDuration(duration).getObjectRequest {
                it.bucket(bucket).key(key).responseContentType("application/json")
            }.build(),
        )
        val expiresAt = OffsetDateTime.ofInstant(clock.instant().plus(duration), ZoneOffset.UTC)
        return OfflinePackageResponse(courseId, course.activeReleaseId, supportLanguage, 1, sha256, signed.url().toString(), expiresAt)
    }

    private fun ensureObject(key: String, sha256: String, bytes: ByteArray) {
        val exists = try {
            s3.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build())
            true
        } catch (_: NoSuchKeyException) {
            false
        } catch (error: software.amazon.awssdk.services.s3.model.S3Exception) {
            if (error.statusCode() == 404) false else throw error
        }
        if (exists) return
        val request = PutObjectRequest.builder()
            .bucket(bucket).key(key).contentType("application/json")
            .metadata(mapOf("sha256" to sha256, "format-version" to "1"))
            .apply {
                if (kmsKeyArn.isNotBlank()) {
                    serverSideEncryption(ServerSideEncryption.AWS_KMS)
                    ssekmsKeyId(kmsKeyArn)
                }
            }.build()
        s3.putObject(request, RequestBody.fromBytes(bytes))
    }
}
