package com.kelimio.api.web

import jakarta.servlet.http.HttpServletRequest
import jakarta.validation.ConstraintViolationException
import org.slf4j.LoggerFactory
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.http.ResponseEntity
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.validation.BindException
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.ServletRequestBindingException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import java.net.URI

sealed class ApiProblem(
    val status: HttpStatus,
    val problemType: String,
    override val message: String,
) : RuntimeException(message)

class NotFoundProblem(message: String) : ApiProblem(HttpStatus.NOT_FOUND, "not-found", message)

class ForbiddenProblem(message: String) : ApiProblem(HttpStatus.FORBIDDEN, "forbidden", message)

class ConflictProblem(message: String) : ApiProblem(HttpStatus.CONFLICT, "conflict", message)

class UnprocessableProblem(message: String) :
    ApiProblem(HttpStatus.UNPROCESSABLE_ENTITY, "unprocessable-entity", message)

@RestControllerAdvice
class ApiExceptionHandler {
    private val logger = LoggerFactory.getLogger(ApiExceptionHandler::class.java)

    @ExceptionHandler(ApiProblem::class)
    fun handleApiProblem(
        exception: ApiProblem,
        request: HttpServletRequest,
    ): ResponseEntity<ProblemDetail> =
        problem(exception.status, exception.problemType, exception.message, request)

    @ExceptionHandler(
        MethodArgumentNotValidException::class,
        BindException::class,
        ConstraintViolationException::class,
        MethodArgumentTypeMismatchException::class,
        HttpMessageNotReadableException::class,
        ServletRequestBindingException::class,
    )
    @Suppress("UNUSED_PARAMETER")
    fun handleBadRequest(
        exception: Exception,
        request: HttpServletRequest,
    ): ResponseEntity<ProblemDetail> =
        problem(HttpStatus.BAD_REQUEST, "invalid-request", "The request is invalid.", request)

    @ExceptionHandler(DataIntegrityViolationException::class)
    fun handleIntegrityViolation(
        exception: DataIntegrityViolationException,
        request: HttpServletRequest,
    ): ResponseEntity<ProblemDetail> {
        logger.info(
            "Database constraint rejected request requestId={} exceptionType={}",
            requestId(request),
            exception.javaClass.name,
        )
        return problem(HttpStatus.CONFLICT, "constraint-conflict", "The request conflicts with current state.", request)
    }

    @ExceptionHandler(Exception::class)
    fun handleUnexpected(
        exception: Exception,
        request: HttpServletRequest,
    ): ResponseEntity<ProblemDetail> {
        logger.error(
            "Unhandled API failure requestId={} exceptionType={}",
            requestId(request),
            exception.javaClass.name,
        )
        return problem(HttpStatus.INTERNAL_SERVER_ERROR, "internal-error", "An unexpected error occurred.", request)
    }

    private fun problem(
        status: HttpStatus,
        type: String,
        detail: String,
        request: HttpServletRequest,
    ): ResponseEntity<ProblemDetail> {
        val body = ProblemDetail.forStatusAndDetail(status, detail)
        body.type = URI.create("https://api.kelimio.invalid/problems/$type")
        body.title = status.reasonPhrase
        body.instance = URI.create(request.requestURI)
        body.setProperty("requestId", requestId(request))
        return ResponseEntity.status(status).body(body)
    }

    private fun requestId(request: HttpServletRequest): Any? =
        request.getAttribute(CorrelationIdFilter.REQUEST_ATTRIBUTE)
}
