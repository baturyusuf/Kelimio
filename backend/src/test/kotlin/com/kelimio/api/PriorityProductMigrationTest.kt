package com.kelimio.api

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.flywaydb.core.Flyway
import org.junit.jupiter.api.BeforeAll
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
class PriorityProductMigrationTest {
    @Test
    fun `V15 permits only one pending deletion request while retaining history`() {
        val userId = insertUser()
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        connection().use { connection ->
            connection.prepareStatement(
                "insert into account_deletion_request(id, user_id, status, requested_at, scheduled_for, correlation_id) values (?, ?, 'CANCELLED', ?, ?, 'test')",
            ).use { statement ->
                statement.setObject(1, UUID.randomUUID())
                statement.setObject(2, userId)
                statement.setObject(3, now)
                statement.setObject(4, now.plusDays(7))
                assertThat(statement.executeUpdate()).isEqualTo(1)
            }
            connection.prepareStatement(
                "insert into account_deletion_request(id, user_id, status, requested_at, scheduled_for, correlation_id) values (?, ?, 'PENDING', ?, ?, 'test')",
            ).use { statement ->
                statement.setObject(1, UUID.randomUUID())
                statement.setObject(2, userId)
                statement.setObject(3, now.plusSeconds(1))
                statement.setObject(4, now.plusDays(7))
                assertThat(statement.executeUpdate()).isEqualTo(1)
                statement.setObject(1, UUID.randomUUID())
                assertThatThrownBy(statement::executeUpdate)
                    .hasMessageContaining("uq_account_deletion_pending_user")
            }
        }
    }

    @Test
    fun `V16 records abandonment without deleting immutable release content`() {
        val userId = insertUser()
        val courseId = UUID.randomUUID()
        val releaseId = UUID.randomUUID()
        val eventId = UUID.randomUUID()
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        connection().use { connection ->
            connection.autoCommit = false
            connection.prepareStatement(
                "insert into course(id, owner_user_id, name, target_language, default_support_language, visibility, publication_status, access_type, created_at, updated_at) values (?, ?, 'Course', 'tr', 'en', 'PRIVATE', 'DRAFT', 'FREE', ?, ?)",
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
                "insert into outbox_event(id, aggregate_type, aggregate_id, event_type, schema_version, payload, correlation_id, occurred_at) values (?, 'course', ?, 'content.release-abandoned.v1', 1, '{}'::jsonb, 'test', ?)",
            ).use { statement ->
                statement.setObject(1, eventId)
                statement.setObject(2, courseId)
                statement.setObject(3, now)
                statement.executeUpdate()
            }
            connection.prepareStatement("update course_release set status = 'ABANDONED' where id = ?").use {
                it.setObject(1, releaseId)
                assertThat(it.executeUpdate()).isEqualTo(1)
            }
            connection.prepareStatement(
                "insert into course_release_abandonment(id, course_id, course_release_id, actor_user_id, outbox_event_id, abandoned_at, correlation_id) values (?, ?, ?, ?, ?, ?, 'test')",
            ).use { statement ->
                statement.setObject(1, UUID.randomUUID())
                statement.setObject(2, courseId)
                statement.setObject(3, releaseId)
                statement.setObject(4, userId)
                statement.setObject(5, eventId)
                statement.setObject(6, now)
                assertThat(statement.executeUpdate()).isEqualTo(1)
            }
            connection.commit()
            connection.createStatement().executeQuery(
                "select status from course_release where id = '$releaseId'",
            ).use { result ->
                assertThat(result.next()).isTrue()
                assertThat(result.getString(1)).isEqualTo("ABANDONED")
            }
        }
    }

    private fun insertUser(): UUID {
        val id = UUID.randomUUID()
        val now = OffsetDateTime.now(ZoneOffset.UTC)
        connection().use { connection ->
            connection.prepareStatement(
                "insert into app_user(id, oidc_subject, display_name, app_locale, active_target_language, time_zone, created_at, updated_at) values (?, ?, 'Tester', 'tr', 'tr', 'UTC', ?, ?)",
            ).use { statement ->
                statement.setObject(1, id)
                statement.setString(2, "subject-$id")
                statement.setObject(3, now)
                statement.setObject(4, now)
                statement.executeUpdate()
            }
        }
        return id
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

        @JvmStatic
        @BeforeAll
        fun migrate() {
            Flyway.configure()
                .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
                .locations("classpath:db/migration")
                .load()
                .migrate()
        }
    }
}
