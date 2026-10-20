// CA-023-08: la tabla de permisos de data-safety.md, la política y la lista blanca del manifiesto de
// release dicen lo mismo, en los dos sentidos.
import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import { checkPermissions, parseAllowed, parsePermissionTable } from "../check.mjs";
import { cloneWorld, edit, read, world } from "./support.mjs";

let base;
before(() => {
  base = world();
});
after(() => base.cleanup());

/** Un mundo nuevo y los errores de permisos tras aplicar [mutate] a él. */
function errorsWith(mutate) {
  const w = cloneWorld(base);
  try {
    mutate(w.paths);
    return checkPermissions(w.paths);
  } finally {
    w.cleanup();
  }
}

const ALLOWED_LINE = /^ALLOWED=\(.*\)$/m;

describe("CA-023-08: caso igual", () => {
  test("CA-023-08: el repositorio real pasa", () => {
    assert.deepEqual(checkPermissions(base.paths), []);
  });

  test("CA-023-08: la lista blanca y la tabla se leen tal cual", () => {
    assert.deepEqual(parseAllowed(read(base.paths.permissionsScript)), [
      "android.permission.INTERNET",
      "android.permission.POST_NOTIFICATIONS",
      "android.permission.RECEIVE_BOOT_COMPLETED",
    ]);
    const rows = parsePermissionTable(read(base.paths.dataSafety));
    assert.deepEqual(
      rows.map((r) => [r.permission, r.status]),
      [
        ["android.permission.INTERNET", "allowed"],
        ["android.permission.POST_NOTIFICATIONS", "allowed"],
        ["android.permission.RECEIVE_BOOT_COMPLETED", "allowed"],
        ["android.permission.ACCESS_LOCAL_NETWORK", "system"],
      ],
    );
  });
});

describe("CA-023-08: un permiso de más en la lista blanca", () => {
  test("CA-023-08: está en ALLOWED y no en la tabla: falla y lo nombra", () => {
    const errors = errorsWith((p) =>
      edit(p.permissionsScript, (t) => t.replace(ALLOWED_LINE, (l) => l.replace(")", ' "android.permission.CAMERA")'))),
    );
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /android\.permission\.CAMERA/);
    assert.match(errors[0], /lista blanca/);
  });

  test("CA-023-08: el permiso interno de receptores no exportados en ALLOWED no cuenta", () => {
    const errors = errorsWith((p) =>
      edit(p.permissionsScript, (t) =>
        t.replace(ALLOWED_LINE, (l) => l.replace(")", ' "dev.example.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION")')),
      ),
    );
    assert.deepEqual(errors, []);
  });
});

describe("CA-023-08: un permiso de más en la tabla", () => {
  test("CA-023-08: fila con «sí» que no está en ALLOWED: falla y lo nombra", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) =>
        t.replace(
          "| android.permission.ACCESS_LOCAL_NETWORK |",
          "| android.permission.CAMERA | cámara | camera | sí |\n| android.permission.ACCESS_LOCAL_NETWORK |",
        ),
      ),
    );
    assert.ok(errors.some((e) => /android\.permission\.CAMERA/.test(e) && /no está en la lista blanca/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: ACCESS_LOCAL_NETWORK marcado «sí» sin estar en ALLOWED falla", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) => t.replace("| red local | local network | sistema, no declarado |", "| red local | local network | sí |")),
    );
    assert.ok(errors.some((e) => /ACCESS_LOCAL_NETWORK/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: un permiso «sistema, no declarado» que sí está en ALLOWED falla", () => {
    const errors = errorsWith((p) =>
      edit(p.permissionsScript, (t) => t.replace(ALLOWED_LINE, (l) => l.replace(")", ' "android.permission.ACCESS_LOCAL_NETWORK")'))),
    );
    assert.ok(errors.some((e) => /ACCESS_LOCAL_NETWORK/.test(e) && /sistema/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: el permiso interno en la tabla se ignora", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) =>
        t.replace(
          "| android.permission.ACCESS_LOCAL_NETWORK |",
          "| dev.example.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | interno | internal | sí |\n| android.permission.ACCESS_LOCAL_NETWORK |",
        ),
      ),
    );
    assert.deepEqual(errors, []);
  });
});

describe("CA-023-08: los nombres de la tabla están en la política", () => {
  test("CA-023-08: si el nombre en español no está en la parte española de la política, falla", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) => t.replace("| Internet | Internet | sí |", "| Conexión a la red | Internet | sí |")),
    );
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /INTERNET/);
    assert.match(errors[0], /Conexión a la red/);
  });

  test("CA-023-08: si el nombre en inglés no está en la parte inglesa, falla", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) => t.replace("| Notificaciones | Notifications | sí |", "| Notificaciones | Alerts | sí |")),
    );
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /POST_NOTIFICATIONS/);
    assert.match(errors[0], /Alerts/);
  });

  test("CA-023-08: un nombre que solo está en la otra mitad de la política no vale", () => {
    // «Notifications» (EN) solo aparece en la parte inglesa: en la columna ES no sirve.
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) => t.replace("| Notificaciones | Notifications | sí |", "| Notifications | Notifications | sí |")),
    );
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /español/);
  });

  test("CA-023-08: el permiso «sistema, no declarado» también debe nombrarse en la política", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) => t.replace("| red local | local network |", "| intranet | local network |")),
    );
    assert.equal(errors.length, 1, errors.join("\n"));
    assert.match(errors[0], /ACCESS_LOCAL_NETWORK/);
  });

  test("CA-023-08: la política que nombra un permiso android.permission.X que no está en la tabla falla", () => {
    const errors = errorsWith((p) =>
      edit(p.policy, (t) => t.replace("- **Internet:** la app", "- **Internet** (android.permission.READ_CONTACTS): la app")),
    );
    assert.ok(errors.some((e) => /READ_CONTACTS/.test(e)), errors.join("\n"));
  });
});

describe("CA-023-08: falla cerrada con lo que no entiende", () => {
  test("CA-023-08: sin línea ALLOWED en el script falla", () => {
    const errors = errorsWith((p) => edit(p.permissionsScript, (t) => t.replace(ALLOWED_LINE, "# sin lista")));
    assert.ok(errors.some((e) => /ALLOWED/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: algo que no es un nombre entre comillas dentro de ALLOWED falla", () => {
    const errors = errorsWith((p) =>
      edit(p.permissionsScript, (t) => t.replace(ALLOWED_LINE, (l) => l.replace(")", " android.permission.CAMERA)"))),
    );
    assert.ok(errors.some((e) => /ALLOWED/.test(e) && /comillas/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: ALLOWED definida dos veces falla", () => {
    const errors = errorsWith((p) => edit(p.permissionsScript, (t) => t.replace(ALLOWED_LINE, (l) => `${l}\n${l}`)));
    assert.ok(errors.some((e) => /ALLOWED/.test(e) && /más de una vez/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: ALLOWED vacío falla", () => {
    const errors = errorsWith((p) => edit(p.permissionsScript, (t) => t.replace(ALLOWED_LINE, "ALLOWED=()")));
    assert.ok(errors.some((e) => /ALLOWED/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: sin tabla de permisos falla", () => {
    const errors = errorsWith((p) => edit(p.dataSafety, (t) => t.replace("| permiso | ES | EN | lista blanca |", "| otra | cosa |")));
    assert.ok(errors.some((e) => /tabla de permisos/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: un valor de «lista blanca» que no es «sí» ni «sistema, no declarado» falla", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) => t.replace("| red local | local network | sistema, no declarado |", "| red local | local network | quizá |")),
    );
    assert.ok(errors.some((e) => /quizá/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: un permiso repetido en la tabla falla", () => {
    const errors = errorsWith((p) =>
      edit(p.dataSafety, (t) =>
        t.replace(
          "| android.permission.ACCESS_LOCAL_NETWORK |",
          "| android.permission.INTERNET | Internet | Internet | sí |\n| android.permission.ACCESS_LOCAL_NETWORK |",
        ),
      ),
    );
    assert.ok(errors.some((e) => /repetido/.test(e) && /INTERNET/.test(e)), errors.join("\n"));
  });

  test("CA-023-08: una política sin su parte inglesa es un error, no una excepción", () => {
    const errors = errorsWith((p) => edit(p.policy, (t) => t.replace("# Privacy policy (EN)", "# Otra cosa")));
    assert.ok(errors.length >= 1);
    assert.ok(errors.every((e) => typeof e === "string"));
  });
});
