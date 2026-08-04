package com.kelimio.api.config

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component
import java.sql.Connection
import javax.sql.DataSource

@Component
@ConditionalOnProperty(name = ["KELIMIO_RUNTIME_ROLE"], havingValue = "migration")
class DatabaseRuntimeRoleBootstrap(
    private val dataSource: DataSource,
    @Value("\${KELIMIO_DB_NAME:kelimio}") private val databaseName: String,
    @Value("\${KELIMIO_DB_RUNTIME_USER}") private val runtimeUsername: String,
    @Value("\${KELIMIO_DB_RUNTIME_PASSWORD}") private val runtimePassword: String,
) : ApplicationRunner {
    private val logger = LoggerFactory.getLogger(DatabaseRuntimeRoleBootstrap::class.java)

    init {
        require(databaseName == "kelimio") { "KELIMIO_DB_NAME must be kelimio." }
        require(runtimeUsername == "kelimio_runtime") {
            "KELIMIO_DB_RUNTIME_USER must be the least-privilege kelimio_runtime role."
        }
        require(runtimePassword.length >= 32 && runtimePassword.none(Char::isWhitespace)) {
            "KELIMIO_DB_RUNTIME_PASSWORD must contain at least 32 non-whitespace characters."
        }
    }

    override fun run(args: ApplicationArguments) {
        dataSource.connection.use { connection ->
            connection.autoCommit = false
            try {
                assertNoMemberships(connection)
                createOrHardenRole(connection)
                grantRuntimePrivileges(connection)
                connection.commit()
            } catch (exception: RuntimeException) {
                connection.rollback()
                throw exception
            }
        }
        logger.info("Least-privilege production database runtime role is ready role={}", runtimeUsername)
    }

    private fun assertNoMemberships(connection: Connection) {
        connection.prepareStatement(
            """
            select count(*)
            from pg_auth_members membership
            join pg_roles member_role on member_role.oid = membership.member
            where member_role.rolname = ?
            """.trimIndent(),
        ).use { statement ->
            statement.setString(1, runtimeUsername)
            statement.executeQuery().use { result ->
                check(result.next() && result.getLong(1) == 0L) {
                    "The runtime database role has unexpected memberships; refusing to continue."
                }
            }
        }
    }

    private fun createOrHardenRole(connection: Connection) {
        val exists = connection.prepareStatement("select 1 from pg_roles where rolname = ?").use { statement ->
            statement.setString(1, runtimeUsername)
            statement.executeQuery().use { it.next() }
        }
        val action = if (exists) "ALTER ROLE" else "CREATE ROLE"
        val sql = connection.prepareStatement("select format('$action %I', ?)").use { statement ->
            statement.setString(1, runtimeUsername)
            statement.executeQuery().use { result ->
                check(result.next())
                result.getString(1)
            }
        }
        connection.createStatement().use { statement ->
            statement.execute(
                "$sql WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS",
            )
        }
        val passwordSql = connection.prepareStatement("select format('ALTER ROLE %I PASSWORD %L', ?, ?)").use {
            it.setString(1, runtimeUsername)
            it.setString(2, runtimePassword)
            it.executeQuery().use { result ->
                check(result.next())
                result.getString(1)
            }
        }
        connection.createStatement().use { it.execute(passwordSql) }
    }

    private fun grantRuntimePrivileges(connection: Connection) {
        val role = quotedIdentifier(runtimeUsername)
        val database = quotedIdentifier(databaseName)
        connection.createStatement().use { statement ->
            listOf(
                "REVOKE CONNECT, TEMPORARY ON DATABASE $database FROM PUBLIC",
                "GRANT CONNECT ON DATABASE $database TO $role",
                "REVOKE CREATE ON SCHEMA public FROM PUBLIC",
                "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM $role",
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $role",
                "REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM $role",
                "GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO $role",
                "REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC",
                "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $role",
                "GRANT USAGE ON SCHEMA public TO $role",
                "REVOKE CREATE ON SCHEMA public FROM $role",
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $role",
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO $role",
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC",
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $role",
            ).forEach(statement::execute)
        }
    }

    private fun quotedIdentifier(value: String): String = "\"${value.replace("\"", "\"\"")}\""
}
