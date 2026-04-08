import asyncio
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

# Free-provider domains that cannot be used as Resend senders without domain verification
_FREE_EMAIL_DOMAINS = {
    "gmail.com", "googlemail.com", "yahoo.com", "yahoo.co.uk",
    "hotmail.com", "hotmail.co.uk", "outlook.com", "live.com",
    "mail.ru", "yandex.ru", "yandex.com", "icloud.com",
}


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
        # Gmail App Passwords are shown with spaces (xxxx xxxx xxxx xxxx) for
        # readability, but the actual credential is the 16 chars without spaces.
        password = settings.MAIL_PASSWORD.replace(" ", "")
        with smtplib.SMTP(settings.MAIL_SERVER, settings.MAIL_PORT, timeout=15) as srv:
            srv.ehlo()
            srv.starttls()
            srv.ehlo()
            srv.login(settings.MAIL_USERNAME, password)
            srv.sendmail(sender, [to], msg.as_string())
        logger.info("✉️ Email sent to %s", to)
        return True
    except Exception as exc:
        logger.error("SMTP error sending to %s: %s", to, exc)
        return False


async def _send(to: str, subject: str, html: str) -> bool:
    smtp_sent = await asyncio.to_thread(_send_sync, to, subject, html)
    if smtp_sent:
        return True
    return await _send_via_resend(to, subject, html)


def _resend_sender() -> str:
    """
    Resend rejects senders whose domain hasn't been verified in the Resend dashboard.
    Free-provider addresses (gmail.com, etc.) can never be verified there.
    Fall back to Resend's built-in sandbox sender when no custom domain is available.
    Note: onboarding@resend.dev only delivers to the Resend account's verified email;
    set RESEND_FROM_EMAIL in .env to a verified custom-domain address for full delivery.
    """
    # Prefer an explicit RESEND_FROM_EMAIL override
    resend_from = getattr(settings, "RESEND_FROM_EMAIL", "").strip()
    if resend_from:
        return resend_from if "<" in resend_from else f"MoodWave <{resend_from}>"

    mail_from = (settings.MAIL_FROM or "").strip()
    if mail_from:
        domain = mail_from.rsplit("@", 1)[-1].lower() if "@" in mail_from else ""
        if domain and domain not in _FREE_EMAIL_DOMAINS:
            # Custom domain — use it directly
            return mail_from if "<" in mail_from else f"MoodWave <{mail_from}>"

    # Fallback to Resend sandbox sender
    return "MoodWave <onboarding@resend.dev>"


async def _send_via_resend(to: str, subject: str, html: str) -> bool:
    if not settings.RESEND_API_KEY:
        return False

    sender = _resend_sender()
    payload = {
        "from": sender,
        "to": [to],
        "subject": subject,
        "html": html,
    }

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            if response.status_code >= 400:
                logger.error(
                    "Resend rejected email to %s: status=%s body=%s",
                    to, response.status_code, response.text[:300],
                )
                return False
            response.raise_for_status()
        logger.info("✉️ Email sent via Resend to %s (from=%s)", to, sender)
        return True
    except Exception as exc:
        logger.error("Resend error sending to %s: %s", to, exc)
        return False


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


def _parse_device(user_agent: str) -> str:
    ua = (user_agent or "").lower()
    if "iphone" in ua:
        return "iPhone"
    if "ipad" in ua:
        return "iPad"
    if "android" in ua:
        return "Android"
    if "mac os" in ua or "macintosh" in ua:
        return "Mac"
    if "windows" in ua:
        return "Windows PC"
    if "linux" in ua:
        return "Linux"
    return "Unknown device"


async def send_login_email(
    email: str,
    first_name: str = "",
    ip_address: str = "",
    user_agent: str = "",
) -> bool:
    name = first_name or "there"
    safe_ip = ip_address or "Unknown"
    device = _parse_device(user_agent)
    html = f"""
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;
                background:#08080f;color:#f0f0ff;padding:32px;border-radius:16px;">
      <div style="text-align:center;margin-bottom:24px;">
        <h1 style="color:#a855f7;font-size:28px;margin:0;">MoodWave</h1>
      </div>
      <h2 style="font-size:20px;margin-bottom:8px;">Hi {name}!</h2>
      <p style="color:#a0a0c0;line-height:1.6;">
        A new sign-in to your MoodWave account was detected.
      </p>
      <div style="background:#1a1a2e;border:1px solid #7c3aed;
                  border-radius:12px;padding:20px;margin:24px 0;">
        <p style="color:#f0f0ff;font-size:15px;margin:0 0 8px;">
          📱 Device: <strong>{device}</strong>
        </p>
        <p style="color:#a0a0c0;font-size:13px;margin:0;">
          🌐 IP: {safe_ip}
        </p>
      </div>
      <div style="text-align:center;margin:24px 0;">
        <p style="color:#a0a0c0;font-size:14px;margin-bottom:16px;">Was this you?</p>
        <a href="mailto:{email}?subject=MoodWave+confirmed"
           style="background:#7c3aed;color:white;padding:14px 32px;
                  border-radius:12px;text-decoration:none;font-size:15px;
                  font-weight:700;display:inline-block;">
          ✓ Yes, that was me
        </a>
      </div>
      <p style="color:#606080;font-size:12px;text-align:center;line-height:1.6;">
        If this wasn't you, change your password immediately at MoodWave.
      </p>
    </div>
    """
    return await _send(email, "MoodWave — New sign-in detected", html)
