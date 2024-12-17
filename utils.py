def validate_credentials(username, password):
    if not (4 <= len(username) <= 20) or not (4 <= len(password) <= 20):
        return False, "Имя и пароль должны быть от 4 до 20 символов."
    if not username.isalnum() or not password.isalnum():
        return False, "Имя и пароль могут содержать только английские буквы и цифры."
    return True, ""
