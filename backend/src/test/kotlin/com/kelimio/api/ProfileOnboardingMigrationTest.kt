package com.kelimio.api

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.flywaydb.core.Flyway
import org.flywaydb.core.api.MigrationVersion
import org.junit.jupiter.api.Test
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.utility.DockerImageName
import java.sql.DriverManager
import java.sql.SQLException
import java.util.UUID

@Testcontainers(disabledWithoutDocker = true)
class ProfileOnboardingMigrationTest {
    @Test
    fun `V4 keeps existing users provisional and enforces the new state constraints`() {
        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .target(MigrationVersion.fromVersion("3"))
            .load()
            .migrate()

        val userId = UUID.randomUUID()
        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use { connection ->
            connection.prepareStatement(
                """
                insert into app_user (
                    id, oidc_subject, email, display_name, username,
                    app_locale, active_target_language, created_at, updated_at
                ) values (?, ?, ?, ?, ?, ?, ?, now(), now())
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, userId)
                statement.setString(2, "legacy-${UUID.randomUUID()}")
                statement.setString(3, "legacy@integration.invalid")
                statement.setString(4, "Legacy User")
                statement.setString(5, "legacy-user")
                statement.setString(6, "tr")
                statement.setString(7, "en")
                assertThat(statement.executeUpdate()).isEqualTo(1)
            }
        }

        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .load()
            .migrate()

        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use { connection ->
            connection.prepareStatement(
                """
                select preferred_support_language, profile_setup_completed_at, profile_version
                from app_user where id = ?
                """.trimIndent(),
            ).use { statement ->
                statement.setObject(1, userId)
                statement.executeQuery().use { result ->
                    assertThat(result.next()).isTrue()
                    assertThat(result.getString("preferred_support_language")).isNull()
                    assertThat(result.getObject("profile_setup_completed_at")).isNull()
                    assertThat(result.getLong("profile_version")).isZero()
                }
            }

            assertThatThrownBy {
                connection.createStatement().use { statement ->
                    statement.executeUpdate(
                        "update app_user set preferred_support_language = 'tr' where id = '$userId'",
                    )
                }
            }.isInstanceOf(SQLException::class.java)
        }
    }

    private class KPostgreSQLContainer(image: DockerImageName) : PostgreSQLContainer<KPostgreSQLContainer>(image)

    companion object {
        @Container
        @JvmStatic
        private val postgres = KPostgreSQLContainer(
            DockerImageName
                .parse("postgres:17.5-alpine@sha256:6567bca8d7bc8c82c5922425a0baee57be8402df92bae5eacad5f01ae9544daa")
                .asCompatibleSubstituteFor("postgres"),
        )
    }
}
