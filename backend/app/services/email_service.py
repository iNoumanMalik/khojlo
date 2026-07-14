import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import settings

logger = logging.getLogger(__name__)

# Khojlo palette (kept in sync with frontend/lib/core/theme/app_colors.dart).
_INK = "#2B2620"
_CREAM = "#FBF6EE"
_EMERALD = "#1D6D5A"
_MUTED = "#8A8478"


def send_email(*, to: str, subject: str, html: str) -> None:
    """Sends an HTML email over SMTP. No-ops (with a log warning) if SMTP isn't configured."""
    if not settings.email_enabled:
        logger.warning("SMTP not configured — skipping email to %s (%s)", to, subject)
        return

    message = MIMEMultipart("alternative")
    message["Subject"] = subject
    message["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    message["To"] = to
    message.attach(MIMEText(html, "html"))

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10) as server:
        if settings.SMTP_USE_TLS:
            server.starttls()
        server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
        server.send_message(message)


def _shell(*, eyebrow: str, heading: str, body_html: str) -> str:
    return f"""\
<!DOCTYPE html>
<html>
  <body style="margin:0;padding:0;background:{_CREAM};font-family:'Helvetica Neue',Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{_CREAM};padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" style="max-width:420px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 10px 28px rgba(43,38,32,0.10);">
            <tr>
              <td style="padding:28px 32px 0 32px;">
                <span style="font-size:11px;font-weight:700;letter-spacing:1.5px;color:{_EMERALD};text-transform:uppercase;">Khojlo</span>
              </td>
            </tr>
            <tr>
              <td style="padding:12px 32px 0 32px;">
                <span style="font-size:10.5px;font-weight:700;letter-spacing:1px;color:{_MUTED};text-transform:uppercase;">{eyebrow}</span>
                <h1 style="margin:6px 0 0 0;font-size:22px;line-height:1.3;color:{_INK};font-weight:600;">{heading}</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 32px 32px 32px;">
                {body_html}
              </td>
            </tr>
          </table>
          <p style="margin:20px 0 0 0;font-size:11px;color:{_MUTED};">
            You're receiving this because a request was made for your Khojlo account.
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>"""


def _otp_block(code: str, minutes: int) -> str:
    digits = "".join(
        f'<td style="width:38px;height:46px;border-radius:10px;background:{_CREAM};'
        f'text-align:center;vertical-align:middle;font-family:monospace;font-size:20px;'
        f'font-weight:700;color:{_INK};">{d}</td><td style="width:6px;"></td>'
        for d in code
    )
    return f"""\
<p style="margin:0 0 18px 0;font-size:14px;line-height:1.6;color:{_INK};">
  Use the code below. It expires in <strong>{minutes} minutes</strong> and can only be used once.
</p>
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 18px 0;">
  <tr>{digits}</tr>
</table>
<p style="margin:0;font-size:12.5px;color:{_MUTED};">
  Didn't request this? You can safely ignore this email.
</p>"""


def send_verify_email_otp(to: str, code: str) -> None:
    html = _shell(
        eyebrow="Verify your email",
        heading="Confirm it's you",
        body_html=_otp_block(code, settings.OTP_EXPIRE_MINUTES),
    )
    send_email(to=to, subject="Your Khojlo verification code", html=html)


def send_password_reset_otp(to: str, code: str) -> None:
    html = _shell(
        eyebrow="Reset your password",
        heading="Here's your reset code",
        body_html=_otp_block(code, settings.OTP_EXPIRE_MINUTES),
    )
    send_email(to=to, subject="Your Khojlo password reset code", html=html)
