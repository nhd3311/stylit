function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

export function getAuthErrorMessage(message: string): string {
  const lower = message.toLowerCase();

  if (lower.includes("invalid login credentials")) {
    return "Email hoặc mật khẩu không đúng.";
  }
  if (lower.includes("user already registered")) {
    return "Email này đã được đăng ký.";
  }
  if (lower.includes("email not confirmed")) {
    return "Vui lòng xác nhận email trước khi đăng nhập.";
  }
  if (lower.includes("password")) {
    return "Mật khẩu phải có ít nhất 6 ký tự.";
  }

  return "Có lỗi xảy ra. Vui lòng thử lại.";
}

export function validateEmail(email: string): string | null {
  if (!email.trim()) {
    return "Vui lòng nhập email.";
  }
  if (!isValidEmail(email)) {
    return "Vui lòng nhập email hợp lệ (có @ và tên miền).";
  }
  return null;
}

export function validatePassword(password: string): string | null {
  if (!password) {
    return "Vui lòng nhập mật khẩu.";
  }
  if (password.length < 6) {
    return "Mật khẩu phải có ít nhất 6 ký tự.";
  }
  return null;
}
