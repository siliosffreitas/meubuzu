from django.contrib.auth.base_user import BaseUserManager


class UserManager(BaseUserManager):
    """Cria usuários a partir do e-mail, sempre normalizado em minúsculas."""

    use_in_migrations = True

    @staticmethod
    def normalize_email_address(email: str) -> str:
        return email.strip().lower()

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        if not email:
            raise ValueError("O e-mail é obrigatório.")
        extra_fields.setdefault("is_active", True)
        user = self.model(email=self.normalize_email_address(email), **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str | None = None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superusuário precisa de is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superusuário precisa de is_superuser=True.")

        return self.create_user(email, password, **extra_fields)
