# Kelimio internal tester checklist

Record tester email only in the private test record, not in this repository.

## Installation

- [ ] Join the internal test through the Play opt-in link.
- [ ] Install/update Kelimio from Google Play rather than sideloading.
- [ ] Record app version, Android version and device model.
- [ ] App launches without a configuration or fatal error.

## Account

- [ ] Create an account with an accessible test email.
- [ ] Receive and complete email verification.
- [ ] Sign in through the hosted authentication page.
- [ ] Complete app language, target language, support language and time zone.
- [ ] After operator group assignment, sign out and sign in again.

## Core MVP

- [ ] Empty catalog offers the bounded starter course.
- [ ] Installing the starter course once succeeds.
- [ ] Repeating installation does not create a duplicate.
- [ ] Course detail opens and enrollment succeeds.
- [ ] Type A multiple-choice question can be answered.
- [ ] Type B inline blank question can be answered.
- [ ] Type C typed-answer question can be answered without the typed value
      reappearing after restart.
- [ ] Type D matching question accepts one complete mapping and does not grade
      tentative pairs locally.
- [ ] Final score, energy and progress are displayed.
- [ ] Refresh/retry does not add duplicate score or energy.
- [ ] Sign-out removes private cached state.
- [ ] A second user on the same device cannot see the first user's state.

## Failure checks

- [ ] Airplane mode or temporary network loss produces a recoverable error.
- [ ] Returning online permits retry or committed-result reconciliation.
- [ ] Invalid/expired session returns to authentication without a crash loop.
- [ ] No answer key appears before submission.
- [ ] No raw Type C answer or Type D mapping appears in visible logs or diagnostics.
- [ ] No teacher/import, payment, advertising or payout UI is presented as available.

## Result

- [ ] Pass
- [ ] Fail — P0
- [ ] Fail — P1/P2

Attach screenshots and logs only to a private issue or protected test record.
