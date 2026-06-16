// These helpers return translation KEYS (under the "validation" namespace).
// Components translate them with next-intl.

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

export function getAuthErrorKey(message: string): string {
  const lower = message.toLowerCase();

  if (lower.includes("invalid login credentials")) {
    return "invalidCredentials";
  }
  if (lower.includes("user already registered")) {
    return "emailRegistered";
  }
  if (lower.includes("email not confirmed")) {
    return "emailNotConfirmed";
  }
  if (lower.includes("password")) {
    return "passwordTooShort";
  }

  return "generic";
}

export function validateEmail(email: string): string | null {
  if (!email.trim()) {
    return "emailRequired";
  }
  if (!isValidEmail(email)) {
    return "emailInvalid";
  }
  return null;
}

export function validatePassword(password: string): string | null {
  if (!password) {
    return "passwordRequired";
  }
  if (password.length < 6) {
    return "passwordTooShort";
  }
  return null;
}
