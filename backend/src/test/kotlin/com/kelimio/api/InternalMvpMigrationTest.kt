package com.kelimio.api

import org.assertj.core.api.Assertions.assertThat
import org.flywaydb.core.Flyway
import org.junit.jupiter.api.Test
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.utility.DockerImageName
import java.sql.DriverManager
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Testcontainers(disabledWithoutDocker = true)
class InternalMvpMigrationTest {
    @Test
    fun `V14 upgrades an existing release and creates internal MVP facts`() {
        migrate(target = "13")
        val userId = UUID.randomUUID()
        val courseId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        connection().use { connection ->
            connection.autoCommit = false
            connection.prepareStatement(
                """
                insert into app_user(
                    id, oidc_subject, email, display_name, username,
                    app_locale, active_target_language, time_zone,
                    created_at, updated_at, preferred_support_language,
                    profile_setup_completed_at, profile_version
                ) values (?, ?, ?, ?, null, 'tr', 'tr', 'UTC', ?, ?, 'en', ?, 1)
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, userId)
                statement.setString(2, "subject-$userId")
                statement.setString(3, "tester@example.com")
                statement.setString(4, "Tester")
                statement.setObject(5, now)
                statement.setObject(6, now)
                statement.setObject(7, now)
                statement.executeUpdate()
            }
            connection.prepareStatement(
                """
                insert into course(
                    id, owner_user_id, name, description, target_language,
                    default_support_language, visibility, publication_status,
                    access_type, created_at, updated_at, active_release_id
                ) values (?, ?, 'Existing Course', 'Existing Description', 'tr', 'en',
                          'PRIVATE', 'DRAFT', 'FREE', ?, ?, null)
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, courseId)
                statement.setObject(2, userId)
                statement.setObject(3, now)
                statement.setObject(4, now)
                statement.executeUpdate()
            }
            connection.prepareStatement(
                "insert into course_support_language(course_id, language_code) values (?, 'en')",
            ).use { statement ->
                statement.setObject(1, courseId)
                statement.executeUpdate()
            }
            connection.prepareStatement(
                "insert into course_release(id, course_id, revision_number, status, created_at) values (?, ?, 1, 'DRAFT', ?)",
            ).use { statement ->
                statement.setObject(1, releaseId)
                statement.setObject(2, courseId)
                statement.setObject(3, now)
                statement.executeUpdate()
            }
            connection.prepareStatement(
                "update course_release set status = 'ACTIVE' where id = ?",
            ).use { statement ->
                statement.setObject(1, releaseId)
                statement.executeUpdate()
            }
            connection.prepareStatement(
                "update course set publication_status = 'PUBLISHED', active_release_id = ?, updated_at = ? where id = ?",
            ).use { statement ->
                statement.setObject(1, releaseId)
                statement.setObject(2, now)
                statement.setObject(3, courseId)
                statement.executeUpdate()
            }
            connection.commit()
        }

        migrate()

        connection().use { connection ->
            connection.prepareStatement(
                "select course_name, course_description, visibility from course_release_metadata where course_release_id = ?",
            ).use { statement ->
                statement.setObject(1, releaseId)
                statement.executeQuery().use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("course_name")).isEqualTo("Existing Course")
                    assertThat(result.getString("course_description")).isEqualTo("Existing Description")
                    assertThat(result.getString("visibility")).isEqualTo("PRIVATE")
                }
            }
            connection.createStatement().use { statement ->
                statement.executeQuery(
                    """
                    select to_regclass('public.rewarded_ad_session') is not null as rewarded,
                           to_regclass('public.teacher_authorization') is not null as teacher,
                           to_regclass('public.full_course_authoring_commit') is not null as editor
                    """.trimIndent(),
                ).use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getBoolean("rewarded")).isTrue()
                    assertThat(result.getBoolean("teacher")).isTrue()
                    assertThat(result.getBoolean("editor")).isTrue()
                }
            }
        }
    }

    private fun migrate(target: String? = null) {
        val configuration = Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .locations("classpath:db/migration")
        if (target != null) {
            configuration.target(target)
        }
        configuration.load().migrate()
    }

    private fun connection() = DriverManager.getConnection(
        postgres.jdbcUrl,
        postgres.username,
        postgres.password,
    )

    private class KPostgreSQLContainer(image: DockerImageName) : PostgreSQLContainer<KPostgreSQLContainer>(image)

    companion object {
        @Container
        @JvmStatic
        private val postgres = KPostgreSQLContainer(DockerImageName.parse("postgres:17.5-alpine"))
            .withDatabaseName("kelimio")
            .withUsername("kelimio")
            .withPassword("kelimio")
    }
}
