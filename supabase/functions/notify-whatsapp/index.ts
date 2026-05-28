// Edge Function: notify-whatsapp
// Envía un mensaje template de WhatsApp via Meta Cloud API (Graph API) y loguea
// el resultado a notificaciones_log. Pensado para ser llamado fire-and-forget
// desde el frontend (un POST por destinatario).
//
// Secrets requeridos en Supabase (Settings > Edge Functions > Secrets):
//   WA_TOKEN            → token permanente del System User "ArgenDreams API"
//   WA_PHONE_NUMBER_ID  → ID del número de teléfono (no el número en sí)
//
// El SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los provee Supabase automáticamente.
//
// Request body:
//   {
//     template: "nueva_tasacion",
//     to: "5491137573604",              // sin + ni espacios
//     params: ["Agustín", "Juan", ...], // en el orden {{1}}, {{2}}, ...
//     lang?: "es_AR",                   // default es_AR; si Meta no la encuentra, retry con "es"
//     evento?: "nueva_tasacion",        // opcional, para log
//     tasacion_id?: "uuid",             // opcional, FK al log
//     destinatario_id?: "uuid"          // opcional, FK al log
//   }

const META_GRAPH_VERSION = "v22.0";
const DEFAULT_LANG = "es_AR";
const FALLBACK_LANG = "es";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Método no permitido" }, 405);
  }

  const token = Deno.env.get("WA_TOKEN");
  const phoneId = Deno.env.get("WA_PHONE_NUMBER_ID");
  if (!token || !phoneId) {
    return json({ error: "WA_TOKEN o WA_PHONE_NUMBER_ID no configurados en Supabase secrets" }, 500);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }

  // Acción especial one-shot: registrar el número para Cloud API.
  // Se corre UNA SOLA VEZ por número. POST con { "action": "register", "pin": "123456" }
  // El pin queda como 2FA del número (si Meta lo pide para reverificar).
  if (body && body.action === "register") {
    const pin = String(body.pin || "000000");
    const url = `https://graph.facebook.com/${META_GRAPH_VERSION}/${phoneId}/register`;
    let res: Response;
    try {
      res = await fetch(url, {
        method: "POST",
        headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ messaging_product: "whatsapp", pin }),
      });
    } catch (e) {
      return json({ error: "Network: " + String(e) }, 502);
    }
    const data = await res.json().catch(() => ({}));
    return json({ status: res.status, ok: res.ok, body: data });
  }

  const {
    template,
    to,
    params = [],
    lang = DEFAULT_LANG,
    evento,
    tasacion_id,
    destinatario_id,
  } = body || {};

  if (!template || typeof template !== "string") {
    return json({ error: "Falta 'template'" }, 400);
  }
  if (!to || typeof to !== "string") {
    return json({ error: "Falta 'to'" }, 400);
  }

  // Normalizar: solo dígitos. Meta acepta el número internacional sin "+".
  const phone = String(to).replace(/[^0-9]/g, "");
  if (phone.length < 10) {
    return json({ error: "Teléfono inválido: " + to }, 400);
  }

  const paramsArr = (Array.isArray(params) ? params : []).map((p) => String(p ?? ""));

  // 1er intento con lang preferido
  let result = await sendTemplate({ token, phoneId, to: phone, template, params: paramsArr, lang });

  // Si Meta devuelve 132001 (template no existe en ese idioma), reintentar con fallback
  let usedLang = lang;
  let retried = false;
  if (!result.ok && result.errorCode === 132001 && lang !== FALLBACK_LANG) {
    retried = true;
    usedLang = FALLBACK_LANG;
    result = await sendTemplate({
      token, phoneId, to: phone, template, params: paramsArr, lang: FALLBACK_LANG,
    });
  }

  const payloadLog = { params: paramsArr, lang: usedLang, retried };

  if (result.ok) {
    await logNotif({
      tasacion_id, destinatario_id, destinatario_telefono: phone,
      template, evento, estado: "ok", meta_message_id: result.messageId,
      payload: payloadLog,
    });
    // BCC silencioso al superadmin (si está configurado el secret y el destinatario
    // original NO es ese mismo número). Se loguea aparte con bcc:true en payload.
    const bccPhone = Deno.env.get("WA_BCC_PHONE");
    if (bccPhone && bccPhone !== phone) {
      const bccResult = await sendTemplate({
        token, phoneId, to: bccPhone, template, params: paramsArr, lang: usedLang,
      });
      await logNotif({
        tasacion_id, destinatario_telefono: bccPhone,
        template, evento: evento ? evento + "_bcc" : "bcc",
        estado: bccResult.ok ? "ok" : "error",
        meta_message_id: bccResult.messageId,
        error_detalle: bccResult.ok ? undefined : bccResult.errorDetail,
        payload: { ...payloadLog, bcc: true, original_to: phone },
      });
    }
    return json({ ok: true, message_id: result.messageId, lang: usedLang });
  }

  await logNotif({
    tasacion_id, destinatario_id, destinatario_telefono: phone,
    template, evento, estado: "error", error_detalle: result.errorDetail,
    payload: { ...payloadLog, error_code: result.errorCode },
  });
  return json({ error: result.errorDetail, code: result.errorCode }, 502);
});

async function sendTemplate(args: {
  token: string;
  phoneId: string;
  to: string;
  template: string;
  params: string[];
  lang: string;
}): Promise<{ ok: boolean; messageId?: string | null; errorDetail?: string; errorCode?: number | null }> {
  const { token, phoneId, to, template, params, lang } = args;
  const url = `https://graph.facebook.com/${META_GRAPH_VERSION}/${phoneId}/messages`;

  // Si la plantilla no tiene variables, components va vacío. Meta lo acepta.
  const components = params.length > 0
    ? [{
      type: "body",
      parameters: params.map((p) => ({ type: "text", text: p })),
    }]
    : [];

  const payload = {
    messaging_product: "whatsapp",
    to,
    type: "template",
    template: {
      name: template,
      language: { code: lang },
      components,
    },
  };

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    return { ok: false, errorDetail: "Network: " + String(e), errorCode: null };
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const errCode = (data && data.error && typeof data.error.code === "number") ? data.error.code : null;
    const errMsg = (data && data.error && data.error.message) ? data.error.message : `HTTP ${res.status}`;
    return { ok: false, errorDetail: errMsg, errorCode: errCode };
  }
  const messageId = data?.messages?.[0]?.id ?? null;
  return { ok: true, messageId };
}

async function logNotif(record: {
  tasacion_id?: string;
  destinatario_id?: string;
  destinatario_telefono: string;
  template: string;
  evento?: string;
  estado: "ok" | "error";
  meta_message_id?: string | null;
  error_detalle?: string;
  payload?: unknown;
}): Promise<void> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return;
  try {
    await fetch(`${supabaseUrl}/rest/v1/notificaciones_log`, {
      method: "POST",
      headers: {
        "apikey": serviceKey,
        "Authorization": `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
      },
      body: JSON.stringify(record),
    });
  } catch (e) {
    console.error("logNotif failed:", e);
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}
