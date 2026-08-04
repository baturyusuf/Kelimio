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
        }
    }

    private fun bootstrap(dataSource: DriverManagerDataSource, password: String) {
        DatabaseRuntimeRoleBootstrap(
            dataSource = dataSource,
            databaseName = "kelimio",
            runtimeUsername = "kelimio_runtime",
            runtimePassword = password,
        ).run(DefaultApplicationArguments())
    }

    private fun runtimeConnection(postgres: PostgreSQLContainer<Nothing>, password: String) =
        DriverManager.getConnection(postgres.jdbcUrl, "kelimio_runtime", password)
}
