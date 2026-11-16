from django.conf import settings
from django.core.mail import send_mail


def send_access_code(email: str, code: str) -> None:
    """Envia o código de acesso. O código nunca é registrado em logs."""

    minutes = max(1, settings.OTP_TTL_SECONDS // 60)
    send_mail(
        subject="Seu código de acesso ao MeuBuzu",
        message=(
            f"Use o código {code} para entrar no MeuBuzu.\n\n"
            f"Ele expira em {minutes} minutos e só pode ser usado uma vez.\n"
            "Se você não pediu este código, ignore este e-mail."
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[email],
        fail_silently=False,
    )
