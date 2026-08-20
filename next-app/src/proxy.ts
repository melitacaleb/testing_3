import { NextResponse, type NextRequest } from "next/server";
import { getSessionFromRequest } from "@/lib/session";

const adminPaths = ["/admin/dashboard", "/admin/motorists", "/admin/reports", "/admin/complaints"];
const userPaths = ["/user/dashboard", "/user/profile", "/user/complaints", "/user/receipts"];

export async function proxy(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  const { pathname } = request.nextUrl;

  const isAdminPath = adminPaths.some((path) => pathname.startsWith(path));
  const isUserPath = userPaths.some((path) => pathname.startsWith(path));

  if (isAdminPath && (!session || session.role !== "admin")) {
    return NextResponse.redirect(new URL("/admin/login", request.url));
  }

  if (isUserPath && (!session || session.role !== "user")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (pathname === "/admin/login" && session?.role === "admin") {
    return NextResponse.redirect(new URL("/admin/dashboard", request.url));
  }

  if ((pathname === "/login" || pathname === "/register") && session?.role === "user") {
    return NextResponse.redirect(new URL("/user/dashboard", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*", "/user/:path*", "/login", "/register"],
};
