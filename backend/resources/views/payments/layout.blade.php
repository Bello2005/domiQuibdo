<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title') · DomiQuibdó</title>
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
            padding: 24px 16px; background: #f8f5ef; color: #1b1c1a;
            font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
        }
        .card { width: 100%; max-width: 420px; background: #fff; border-radius: 24px; padding: 28px 24px; text-align: center; box-shadow: 0 2px 12px rgba(0, 0, 0, .06); }
        .badge { width: 64px; height: 64px; border-radius: 18px; margin: 0 auto 16px; display: grid; place-items: center; font-size: 30px; color: #fff; background: #e07b2e; }
        .ok { background: #1d5e42; } .bad { background: #b3261e; } .wait { background: #8a6d00; }
        h1 { font-size: 22px; margin: 0 0 8px; }
        p { margin: 0 0 12px; color: #4a4d48; line-height: 1.45; }
        .amount { font-size: 28px; font-weight: 700; color: #1b1c1a; margin: 12px 0 20px; }
        button, .button { display: block; width: 100%; border: 0; border-radius: 16px; padding: 16px; font-size: 16px; font-weight: 600; background: #1d5e42; color: #fff; text-decoration: none; cursor: pointer; }
        .muted { font-size: 13px; color: #6b6e68; margin-top: 16px; }
    </style>
</head>
<body>
    <main class="card">
        @yield('content')
    </main>
</body>
</html>
