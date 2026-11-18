import { supabase } from "./supabase";

/** Validate persisted identity against Auth, including deleted accounts. */
export async function validatedUser() {
  const { data, error } = await supabase.auth.getUser();
  if (error) {
    if ([401, 403, 404].includes(error.status ?? 0) ||
        ["session_not_found", "user_not_found", "refresh_token_not_found"].includes(error.code ?? "") ||
        error.name === "AuthSessionMissingError") {
      await supabase.auth.signOut({ scope: "local" });
      return null;
    }
    throw new Error("No se pudo comprobar tu cuenta. Revisa tu conexión e inténtalo de nuevo.");
  }
  return data.user;
}

export async function leaveAccount() {
  // Local scope clears this browser without signing out the mobile app.
  await supabase.auth.signOut({ scope: "local" });
  const { data } = await supabase.auth.getSession();
  if (data.session) throw new Error("No se pudo cerrar la sesión. Inténtalo de nuevo.");
}
