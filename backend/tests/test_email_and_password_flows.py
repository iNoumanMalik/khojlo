from tests.conftest import auth, login, register

PREFIX = "/api/v1"


def _code_for(sent_emails, purpose, email):
    matches = [c for p, to, c in sent_emails if p == purpose and to == email]
    assert matches, f"no {purpose} email captured for {email}"
    return matches[-1]


def test_new_user_is_unverified_and_gets_otp_email(client, sent_emails):
    r = register(client, "verify@khojlo.app")
    assert r.status_code == 201, r.text
    assert r.json()["is_verified"] is False
    assert _code_for(sent_emails, "verify_email", "verify@khojlo.app")


def test_verify_email_wrong_then_right_code(client, sent_emails):
    register(client, "verify2@khojlo.app")
    token = login(client, "verify2@khojlo.app")
    code = _code_for(sent_emails, "verify_email", "verify2@khojlo.app")

    bad = client.post(
        f"{PREFIX}/auth/email/verify", headers=auth(token), json={"code": "000000"}
    )
    assert bad.status_code == 400

    good = client.post(
        f"{PREFIX}/auth/email/verify", headers=auth(token), json={"code": code}
    )
    assert good.status_code == 200, good.text
    assert good.json()["is_verified"] is True


def test_resend_verification_is_rate_limited(client):
    register(client, "verify3@khojlo.app")
    token = login(client, "verify3@khojlo.app")
    resend = client.post(f"{PREFIX}/auth/email/verify/send", headers=auth(token))
    assert resend.status_code == 429


def test_forgot_password_unknown_email_is_generic(client, sent_emails):
    r = client.post(f"{PREFIX}/auth/password/forgot", json={"email": "nobody@khojlo.app"})
    assert r.status_code == 200
    assert "expires_in_minutes" in r.json()
    assert not sent_emails


def test_forgot_password_full_flow(client, sent_emails):
    register(client, "reset@khojlo.app")
    r = client.post(f"{PREFIX}/auth/password/forgot", json={"email": "reset@khojlo.app"})
    assert r.status_code == 200
    code = _code_for(sent_emails, "reset_password", "reset@khojlo.app")

    bad = client.post(
        f"{PREFIX}/auth/password/forgot/verify",
        json={"email": "reset@khojlo.app", "code": "111111"},
    )
    assert bad.status_code == 400

    ok = client.post(
        f"{PREFIX}/auth/password/forgot/verify",
        json={"email": "reset@khojlo.app", "code": code},
    )
    assert ok.status_code == 200, ok.text
    reset_token = ok.json()["reset_token"]

    reset = client.post(
        f"{PREFIX}/auth/password/reset",
        json={"reset_token": reset_token, "new_password": "newpassword456"},
    )
    assert reset.status_code == 200

    # old password no longer works, new one does
    old = client.post(
        f"{PREFIX}/auth/login", json={"email": "reset@khojlo.app", "password": "password123"}
    )
    assert old.status_code == 401
    new = client.post(
        f"{PREFIX}/auth/login", json={"email": "reset@khojlo.app", "password": "newpassword456"}
    )
    assert new.status_code == 200


def test_reset_password_rejects_garbage_token(client):
    r = client.post(
        f"{PREFIX}/auth/password/reset",
        json={"reset_token": "not-a-real-token", "new_password": "whatever123"},
    )
    assert r.status_code == 401
