import asyncio
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.config import settings

logger = logging.getLogger(__name__)


def _send_sync(to: str, subject: str, html: str) -> bool:
    """SMTP send via Gmail — runs in a thread so it doesn't block the event loop."""
    if not settings.MAIL_USERNAME or not settings.MAIL_PASSWORD:
        logger.info("📧 [NO SMTP] Code for %s | %s", to, subject)
        return False

    sender = settings.MAIL_FROM or settings.MAIL_USERNAME

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = to
    msg.attach(MIMEText(html, "html", "utf-8"))

    try:
        with smtplib.SMTP(settings.MAIL_SERVER, settings.MAIL_PORT, timeout=15) as srv:
            srv.ehlo()
            srv.starttls()
            srv.ehlo()
            srv.login(settings.MAIL_USERNAME, settings.MAIL_PASSWORD)
            srv.sendmail(sender, [to], msg.as_string())
        logger.info("✉️ Email sent to %s", to)
        return True
    except Exception as exc:
        logger.error("SMTP error sending to %s: %s", to, exc)
        return False


async def _send(to: str, subject: str, html: str) -> bool:
    return await asyncio.to_thread(_send_sync, to, subject, html)


async def send_verification_email(email: str, code: str, first_name: str = "") -> bool:
    name = first_name or "there"
    html = f"""
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;
                background:#08080f;color:#f0f0ff;padding:32px;border-radius:16px;">
      <div style="text-align:center;margin-bottom:24px;">
        <h1 style="color:#a855f7;font-size:28px;margin:0;">MoodWave</h1>
      </div>
      <h2 style="font-size:20px;margin-bottom:8px;">Hi {name}!</h2>
      <p style="color:#a0a0c0;line-height:1.6;">
        Welcome to MoodWave! Please verify your email address
        to start discovering music that matches your mood.
      </p>
      <div style="background:#1a1a2e;border:1px solid #a855f7;
                  border-radius:12px;padding:24px;text-align:center;margin:24px 0;">
        <p style="color:#a0a0c0;font-size:13px;margin:0 0 8px;">Your verification code:</p>
        <h1 style="color:#a855f7;font-size:42px;letter-spacing:8px;margin:0;">{code}</h1>
        <p style="color:#606080;font-size:12px;margin:8px 0 0;">Valid for 15 minutes</p>
      </div>
      <p style="color:#606080;font-size:12px;text-align:center;">
        If you didn't create a MoodWave account, ignore this email.
      </p>
    </div>
    """
    return await _send(email, f"MoodWave — {code} is your verification code", html)


async def send_reset_email(email: str, code: str, first_name: str = "") -> bool:
    name = first_name or "there"
    html = f"""
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;
                background:#08080f;color:#f0f0ff;padding:32px;border-radius:16px;">
      <div style="text-align:center;margin-bottom:24px;">
        <h1 style="color:#a855f7;font-size:28px;margin:0;">MoodWave</h1>
      </div>
      <h2 style="font-size:20px;margin-bottom:8px;">Hi {name}!</h2>
      <p style="color:#a0a0c0;line-height:1.6;">
        You requested to reset your password.
        Use the code below to create a new password.
      </p>
      <div style="background:#1a1a2e;border:1px solid #ec4899;
                  border-radius:12px;padding:24px;text-align:center;margin:24px 0;">
        <p style="color:#a0a0c0;font-size:13px;margin:0 0 8px;">Your reset code:</p>
        <h1 style="color:#ec4899;font-size:42px;letter-spacing:8px;margin:0;">{code}</h1>
        <p style="color:#606080;font-size:12px;margin:8px 0 0;">
          Valid for 15 minutes - One time use
        </p>
      </div>
      <p style="color:#606080;font-size:13px;line-height:1.6;">
        If you didn't request this, your account is safe. Just ignore this email.
      </p>
    </div>
    """
    return await _send(email, f"MoodWave — {code} is your password reset code", html)


async def send_account_deletion_email(
    email: str, first_name: str = "", days: int = 0
) -> None:
    name = first_name or "User"
    if days > 0:
        subject = "MoodWave — Account deactivated"
        html = f"""
        <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;
                    background:#08080f;color:#f0f0ff;padding:32px;border-radius:16px;">
          <div style="text-align:center;margin-bottom:24px;">
            <h1 style="color:#a855f7;font-size:28px;margin:0;">MoodWave</h1>
          </div>
          <h2 style="font-size:20px;">Hi {name}, we'll miss you</h2>
          <p style="color:#a0a0c0;line-height:1.6;">
            Your account has been <strong style="color:#f59e0b;">deactivated</strong>.
          </p>
          <div style="background:#1a1a2e;border:1px solid #f59e0b;
                      border-radius:12px;padding:20px;margin:24px 0;">
            <p style="color:#f59e0b;font-size:14px;margin:0;">
              Your account will be permanently deleted in
              <strong>{days} days</strong> unless you log back in.
            </p>
          </div>
          <p style="color:#a0a0c0;line-height:1.6;">
            Changed your mind? Simply log in to MoodWave before {days} days
            and your account will be fully restored.
          </p>
        </div>
        """
    else:
        subject = "MoodWave — Account deleted"
        html = f"""
        <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;
                    background:#08080f;color:#f0f0ff;padding:32px;border-radius:16px;">
          <div style="text-align:center;margin-bottom:24px;">
            <h1 style="color:#a855f7;font-size:28px;margin:0;">MoodWave</h1>
          </div>
          <h2 style="font-size:20px;">Goodbye {name}</h2>
          <p style="color:#a0a0c0;line-height:1.6;">
            Your MoodWave account and all data have been permanently deleted as requested.
          </p>
          <p style="color:#a0a0c0;line-height:1.6;">
            We hope to see you again someday.
            You can always create a new account at any time.
          </p>
        </div>
        """
    await _send(email, subject, html)


async def send_reactivation_email(email: str, first_name: str = "") -> None:
    name = first_name or "User"
    html = f"""
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;
                background:#08080f;color:#f0f0ff;padding:32px;border-radius:16px;">
      <div style="text-align:center;margin-bottom:24px;">
        <h1 style="color:#a855f7;font-size:28px;margin:0;">MoodWave</h1>
      </div>
      <h2 style="font-size:20px;">Welcome back, {name}!</h2>
      <p style="color:#a0a0c0;line-height:1.6;">
        Your account has been fully restored.
        All your music, matches, and friends are still here!
      </p>
    </div>
    """
    await _send(email, "MoodWave — Welcome back!", html)
