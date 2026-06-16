function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

export function getAuthErrorMessage(message: string): string {
  const lower = message.toLowerCase();

  if (lower.includes("invalid login credentials")) {
    return "Incorrect email or password.";
  }
  if (lower.includes("user already registered")) {
    return "This email is already registered.";
  }
  if (lower.includes("email not confirmed")) {
    return "Please confirm your email before logging in.";
  }
  if (lower.includes("password")) {
    return "Password must be at least 6 characters.";
  }

  return "Something went wrong. Please try again.";
}

export function validateEmail(email: string): string | null {
  if (!email.trim()) {
    return "Please enter your email.";
  }
  if (!isValidEmail(email)) {
    return "Please enter a valid email (with @ and a domain).";
  }
  return null;
}

export function validatePassword(password: string): string | null {
  if (!password) {
    return "Please enter your password.";
  }
  if (password.length < 6) {
    return "Password must be at least 6 characters.";
  }
  return null;
}
