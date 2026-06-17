"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase-client";

function downloadJson(filename: string, data: unknown) {
  const blob = new Blob([JSON.stringify(data, null, 2)], {
    type: "application/json",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

export function AccountActions() {
  const t = useTranslations("settings");
  const router = useRouter();
  const [busy, setBusy] = useState<string | null>(null);
  const [showDelete, setShowDelete] = useState(false);

  async function signOutEverywhere() {
    setBusy("signout");
    const supabase = createClient();
    await supabase.auth.signOut({ scope: "global" });
    router.push("/login");
    router.refresh();
  }

  async function exportData() {
    setBusy("export");
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { data: wardrobe } = await supabase
      .from("wardrobe_items")
      .select("id, name, category, image_path, created_at");
    downloadJson("fitcheck-data.json", {
      exportedAt: new Date().toISOString(),
      account: user
        ? { id: user.id, email: user.email, createdAt: user.created_at }
        : null,
      wardrobe: wardrobe ?? [],
    });
    setBusy(null);
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm font-medium">{t("signOutEverywhere")}</p>
          <p className="text-sm text-muted-foreground">
            {t("signOutEverywhereDesc")}
          </p>
        </div>
        <button
          type="button"
          disabled={busy !== null}
          onClick={signOutEverywhere}
          className="shrink-0 rounded-lg border border-border bg-background px-4 py-2 text-sm font-medium text-foreground transition hover:bg-muted disabled:opacity-60"
        >
          {t("signOutAll")}
        </button>
      </div>

      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm font-medium">{t("exportData")}</p>
          <p className="text-sm text-muted-foreground">{t("exportDataDesc")}</p>
        </div>
        <button
          type="button"
          disabled={busy !== null}
          onClick={exportData}
          className="shrink-0 rounded-lg border border-border bg-background px-4 py-2 text-sm font-medium text-foreground transition hover:bg-muted disabled:opacity-60"
        >
          {busy === "export" ? "..." : t("export")}
        </button>
      </div>

      <div className="rounded-xl border border-red-500/30 bg-red-500/5 p-4">
        <p className="text-sm font-semibold text-red-400">{t("dangerZone")}</p>
        <div className="mt-2 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-sm font-medium">{t("deleteAccount")}</p>
            <p className="text-sm text-muted-foreground">
              {t("deleteAccountDesc")}
            </p>
          </div>
          <button
            type="button"
            onClick={() => setShowDelete(true)}
            className="shrink-0 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-500"
          >
            {t("deleteAccount")}
          </button>
        </div>
      </div>

      {showDelete && <DeleteModal onClose={() => setShowDelete(false)} />}
    </div>
  );
}

function DeleteModal({ onClose }: { onClose: () => void }) {
  const t = useTranslations("settings");
  const router = useRouter();
  const [confirmText, setConfirmText] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const confirmWord = t("deleteConfirmWord");

  async function handleDelete() {
    setDeleting(true);
    setError(null);
    const res = await fetch("/api/account/delete", { method: "POST" });
    if (!res.ok) {
      setError(t("deleteError"));
      setDeleting(false);
      return;
    }
    router.push("/");
    router.refresh();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="w-full max-w-md rounded-2xl border border-border bg-background p-6">
        <h2 className="text-lg font-semibold text-foreground">
          {t("deleteConfirmTitle")}
        </h2>
        <p className="mt-2 text-sm text-muted-foreground">
          {t("deleteConfirmBody")}
        </p>
        <input
          type="text"
          value={confirmText}
          onChange={(e) => setConfirmText(e.target.value)}
          placeholder={confirmWord}
          className="mt-4 h-11 w-full rounded-xl border border-border bg-input px-4 text-sm text-foreground placeholder:text-muted-foreground outline-none transition focus:border-red-500 focus:ring-2 focus:ring-red-500/20"
        />
        {error && (
          <p className="mt-3 text-sm text-red-400" role="alert">
            {error}
          </p>
        )}
        <div className="mt-5 flex gap-3">
          <button
            type="button"
            onClick={onClose}
            disabled={deleting}
            className="h-11 flex-1 rounded-xl border border-border text-sm font-medium text-muted-foreground transition hover:text-foreground disabled:opacity-50"
          >
            {t("cancel")}
          </button>
          <button
            type="button"
            disabled={confirmText !== confirmWord || deleting}
            onClick={handleDelete}
            className="h-11 flex-1 rounded-xl bg-red-600 text-sm font-semibold text-white transition hover:bg-red-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {deleting ? t("deleting") : t("confirmDelete")}
          </button>
        </div>
      </div>
    </div>
  );
}
