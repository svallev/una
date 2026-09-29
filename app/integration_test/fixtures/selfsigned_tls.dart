// Certificado autofirmado de PRUEBAS para el servidor https local de
// `web_flow_test.dart` (spec 009, T-009-18, CA-009-10): sin él no se puede
// servir https en el emulador, y la app **nunca** debe aceptarlo. Es un par de
// claves desechable, generado solo para esto (no protege nada ni se usa fuera
// de los tests de integración); no es un secreto real.
//
// Generado con (válido 100 años para que no caduque):
//   openssl req -x509 -newkey rsa:2048 -nodes -keyout k.pem -out c.pem \
//     -days 36500 -subj "/CN=una-test-selfsigned" \
//     -addext "subjectAltName=IP:127.0.0.1"
//   openssl pkcs8 -topk8 -nocrypt -in k.pem -out k8.pem
// Las líneas van sin las marcas BEGIN/END, que se añaden abajo.

const _certBody = [
  'MIIC1DCCAbygAwIBAgIJAO3nuMURbvLmMA0GCSqGSIb3DQEBCwUAMB4xHDAaBgNV',
  'BAMME3VuYS10ZXN0LXNlbGZzaWduZWQwIBcNMjYwOTI5MTIxMjI3WhgPMjEyNjA5',
  'MDUxMjEyMjdaMB4xHDAaBgNVBAMME3VuYS10ZXN0LXNlbGZzaWduZWQwggEiMA0G',
  'CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDZasie4pyCi7PjYIm6IgZdFX6od8kO',
  'CUOpTsan6gUkdj4puwr1/7AatdoDmvNPJ/dQPemo7erF03emcjOZI+RntZqba1Hp',
  '6m/C2WOb2BP/60MaMClBGnst5rtLPzpOilgM4p3TbZlWqGYDYmWscQ9qQWV65mK+',
  '8g9vhk1NBzVnhd1adaDbC/ceg51Dc3BT/wV/WgBiRt9powrC44A8JtniikjFdbal',
  'zppLcxsRE6xpWZa08ckIO5hwni2HerDV7dsCKjWVG5SJcpfLNL/ODoMuKriWEPbd',
  'UuMZsXG2584xsEzirDbKoLKwQH4JpGAyvhfWCiHgiUBIwKWR6phFjzMXAgMBAAGj',
  'EzARMA8GA1UdEQQIMAaHBH8AAAEwDQYJKoZIhvcNAQELBQADggEBAK0HMe3H0SHw',
  '3Bb+oHd2VHj2JvsF9qBIP0wEgAIR4si9R9U7TRcq7tZ/jIhP2rs5UAkTdb5WGE9n',
  'CMkIxNm6RZ4zgxi++i5YMOqPO2nYIQvaORuUMqXyKY4Sslxkv6r0lCc4oaJyMzk+',
  '6r3yd3tZcxYE0/iGhGdvKCR3ozS9ZbCm82BP1nvtIN5xAKSo7Btdh692TYt/OPmj',
  'ef9NxeEprNO6XZDo282RUNk0XkMuF/05hjqE2COYsgFvDW3i1BCJOhwFBJsEyeeA',
  '8Ct/jhVRi83NrruDTf1r9MntyTkUs6+yZ0L5vbQkowkKywcRsVXssqBuZpR8+5ST',
  'RDIEfE+wHy4=',
];

const _keyBody = [
  'MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDZasie4pyCi7Pj',
  'YIm6IgZdFX6od8kOCUOpTsan6gUkdj4puwr1/7AatdoDmvNPJ/dQPemo7erF03em',
  'cjOZI+RntZqba1Hp6m/C2WOb2BP/60MaMClBGnst5rtLPzpOilgM4p3TbZlWqGYD',
  'YmWscQ9qQWV65mK+8g9vhk1NBzVnhd1adaDbC/ceg51Dc3BT/wV/WgBiRt9powrC',
  '44A8JtniikjFdbalzppLcxsRE6xpWZa08ckIO5hwni2HerDV7dsCKjWVG5SJcpfL',
  'NL/ODoMuKriWEPbdUuMZsXG2584xsEzirDbKoLKwQH4JpGAyvhfWCiHgiUBIwKWR',
  '6phFjzMXAgMBAAECggEAYbI7LjI0E/FExzKVEN/DLka/YGJbJQSCs+yjFcbxwp2j',
  'd0sGNN5NOuNmcOJK3NHfrt3zRiaKrZRFmrSMfQ8EzplrPNVvvIXM7KiUuu3QptoH',
  'kBf+IbQNj+WzWa+yuqItyLR4KQ6BrdAD7xdjCqbPP3bda+lki9rnlryptag8liRb',
  '9jks4z6YFETQcoEaxt3idaoOfbQyLFc4n7HQorDsD5xH/Jrvj92yWnGvCI5ZmNVq',
  'A14Q0Ze20iIFi+C3jFQXYgXMWDeoIclgyf7Gd/L4NEWOhBDGBXMfZ2W3P1Vk0qVU',
  '2Wi72jMH0H1nLJnDy7ae1p9vx/Qmx3YrAMjtAtHEsQKBgQDukiK6prl1KPtlvmeb',
  'Ie9//CuX7rLID4gVkijEJXI5bynDqGn/5BkbsZiWjZcJDdPy+dmAqOtcVtByMCwA',
  'E1/GNKD0y2szFhuBQm5PUe9i5syZXVYP/nbeTVPqJ331ldINDAxOQnr3+xiBd5FD',
  '2b8tRYuStTE9E2kFyNdlte+4aQKBgQDpTQVtIiZV8pp99M6oYic5eFPzoxjcQtJw',
  '7VrbWCQ/OT523dtnzMgWQfwGZMD48D3fHVVtd+JGAxuLq2awKOaYiRg5O8adQ2Bi',
  'cDH1gehFny18i0+e7x9vJw7uOVsebAVElkYmoGAywxbUXY+QnL7PMCXD95hRIr+Y',
  '1xR8YB4ffwKBgQCffmdlba0zHJDltmPBnPBnGgly64vuoCOUeEB00awJpb3AJsmm',
  '37HBh/vBOyusS+hU2qCEmWmwNAHrNTVVX555/hlVTuF+J9t/kQ/6S4bFEhPavEGb',
  'M734ZK4jLv/QvbbOLi3T7DIVs3LwqyUcvWhINeRX0nb2pBFkYp9OSlHXcQKBgQCU',
  'INYgK72hdo8HCEeqe9+hyrerCtQ/DaJmFx5IBJfHGMaDXGvxZQFpuG2XdaNcq9Ts',
  '88gI4ERn5ZM4xBRIJz/6e5lIxZ5evafV+JyP3/KlOeL8n8tnAza3MVp2gS5Mi5Nw',
  'r+VMoylRMbMuFVWRISS5kj14Rp2Mbn6uQWl9at3VawKBgEu87q1hluA9fk1XFmhH',
  'E7U2QijZ1oQzrM2fniZdMAv875zgtH3bTNHTpztuJlYE9hC9kAGBoE4zHCINU06A',
  '+gmnre7SeCgGX0JlytFHMPS0yb1ujTFHscuZ3ccQyDQZ9IkkPoTXGMfFsjlwa7rD',
  'foTHJMxyJDz5hs1EWgBc/vWD',
];

String _pem(String label, List<String> body) =>
    '-----BEGIN $label-----\n${body.join('\n')}\n-----END $label-----\n';

/// El certificado autofirmado, en PEM.
final selfSignedCertPem = _pem('CERTIFICATE', _certBody);

/// Su clave privada (PKCS#8, sin contraseña), en PEM.
final selfSignedKeyPem = _pem('PRIVATE KEY', _keyBody);
