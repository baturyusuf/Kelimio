package com.kelimio.api.config

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.boot.DefaultApplicationArguments
import org.springframework.jdbc.datasource.DriverManagerDataSource
import org.testcontainers.containers.PostgreSQLContainer
import java.sql.DriverManager

class DatabaseRuntimeRoleBootstrapTest {
    @Test
    fun `bootstrap creates a rotatable dml-only runtime role`() {
        val database = PostgreSQLContainer<Nothing>("postgres:17.5-alpine")
        database.withDatabaseName("kelimio")
        database.use { postgres ->
            postgres.start()
            val admin = DriverManagerDataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            admin.connection.use { connection ->
                connection.createStatement().use {
                    it.execute("create table runtime_proof(id bigint generated always as identity primary key, value text not null)")
                    listOf(
                        "course_import",
                        "course_import_artifact",
                        "course_import_dead_letter",
                        "course_import_dispatch_alert",
                        "course_import_preview",
                        "course_import_preview_issue",
                        "course_import_preview_row",
                        "course_import_processing_attempt",
                        "course_import_scan",
                        "outbox_delivery",
                        "outbox_event",
                    ).forEach { table -> it.execute("create table $table(id bigint primary key, value text)") }
                }
            }

            bootstrap(admin, "A-production-runtime-password-0001!")

            runtimeConnection(postgres, "A-production-runtime-password-0001!").use { connection ->
                connection.createStatement().use {
                    assertThat(it.executeUpdate("insert into runtime_proof(value) values ('allowed')")).isEqualTo(1)
                    it.executeQuery("select value from runtime_proof").use { result ->
                        assertThat(result.next()).isTrue()
                        assertThat(result.getString(1)).isEqualTo("allowed")
                    }
                }
                assertThatThrownBy {
                    connection.createStatement().use { it.execute("create table forbidden(id integer)") }
                }.hasMessageContaining("permission denied")
            }
            DriverManager.getConnection(
                postgres.jdbcUrl,
                "kelimio_worker",
                "A-production-worker-password-0001!",
            ).use { connection ->
                connection.createStatement().use {
                    assertThat(it.executeUpdate("insert into course_import(id, value) values (1, 'allowed')"))
                        .isEqualTo(1)
                }
                assertThatThrownBy {
                    connection.createStatement().use { it.executeQuery("select * from runtime_proof") }
                }.hasMessageContaining("permission denied")
            }

            admin.connection.use { connection ->
                connection.createStatement().use {
                    it.execute("create table future_runtime_proof(id bigint primary key)")
                }
            }
            runtimeConnection(postgres, "A-production-runtime-password-0001!").use { connection ->
                connection.createStatement().use {
                    assertThat(it.executeUpdate("insert into future_runtime_proof(id) values (1)")).isEqualTo(1)
                }
            }

            bootstrap(admin, "A-production-runtime-password-0002!")

            assertThatThrownBy { runtimeConnection(postgres, "A-production-runtime-password-0001!") }
                .hasMessageContaining("password authentication failed")
            runtimeConnection(postgres, "A-production-runtime-password-0002!").use { connection ->
                connection.prepareStatement(
                    "select rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls from pg_roles where rolname = ?",
                ).use { statement ->
                    statement.setString(1, "kelimio_runtime")
                    statement.executeQuery().use { result ->
                        assertThat(result.next()).isTrue()
                        (1..5).forEach { assertThat(result.getBoolean(it)).isFalse() }
                    }
                }
            }

            admin.connection.use { connection ->
                connection.createStatement().use {
                    it.execute("alter role kelimio_runtime with superuser")
                }
            }
            assertThatThrownBy {
                bootstrap(admin, "A-production-runtime-password-0003!")
            }.hasMessageContaining("unsafe attributes")
        }
    }

    private fun bootstrap(dataSource: DriverManagerDataSource, password: String) {
        DatabaseRuntimeRoleBootstrap(
            dataSource = dataSource,
            databaseName = "kelimio",
            runtimeUsername = "kelimio_runtime",
            runtimePassword = password,
            workerUsername = "kelimio_worker",
            workerPassword = "A-production-worker-password-0001!",
        ).run(DefaultApplicationArguments())
    }

    private fun runtimeConnection(postgres: PostgreSQLContainer<Nothing>, password: String) =
        DriverManager.getConnection(postgres.jdbcUrl, "kelimio_runtime", password)
}
