<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DomiQuibdó API</title>
    <style>
        :root {
            color-scheme: dark;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: radial-gradient(circle at 20% 20%, #14532d 0%, #052e16 45%, #020617 100%);
            color: #f1f5f9;
            padding: 24px;
        }
        .card {
            max-width: 560px;
            width: 100%;
            background: rgba(15, 23, 42, 0.55);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 20px;
            padding: 40px;
            backdrop-filter: blur(12px);
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.4);
        }
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(34, 197, 94, 0.15);
            border: 1px solid rgba(34, 197, 94, 0.35);
            color: #4ade80;
            font-size: 13px;
            font-weight: 600;
            padding: 6px 14px;
            border-radius: 999px;
            margin-bottom: 24px;
        }
        .badge .dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #4ade80;
            box-shadow: 0 0 8px #4ade80;
        }
        h1 {
            margin: 0 0 8px;
            font-size: 32px;
            font-weight: 800;
            letter-spacing: -0.02em;
        }
        .subtitle {
            margin: 0 0 28px;
            color: #94a3b8;
            font-size: 15px;
            line-height: 1.6;
        }
        .features {
            display: grid;
            gap: 12px;
            margin-bottom: 28px;
        }
        .feature {
            display: flex;
            align-items: flex-start;
            gap: 12px;
            font-size: 14px;
            color: #cbd5e1;
        }
        .feature svg {
            flex-shrink: 0;
            margin-top: 2px;
            color: #4ade80;
        }
        .meta {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            padding-top: 24px;
            border-top: 1px solid rgba(255, 255, 255, 0.08);
        }
        .chip {
            font-size: 12px;
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            background: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.08);
            color: #94a3b8;
            padding: 5px 10px;
            border-radius: 8px;
        }
        footer {
            margin-top: 20px;
            font-size: 13px;
            color: #64748b;
        }
        footer a { color: #4ade80; text-decoration: none; }
        footer a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="card">
        <span class="badge"><span class="dot"></span> API en línea</span>

        <h1>DomiQuibdó</h1>
        <p class="subtitle">
            API de domicilios para restaurantes pequeños de Quibdó, Chocó.
            Inspirada en Aki Quibdo, con la seguridad del repartidor y del cliente
            como requisito de diseño desde el primer día.
        </p>

        <div class="features">
            <div class="feature">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>
                Código de verificación de entrega
            </div>
            <div class="feature">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>
                Botón SOS y ubicación compartida en tiempo real
            </div>
            <div class="feature">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>
                Zonas de cobertura por barrio
            </div>
        </div>

        <div class="meta">
            <span class="chip">Laravel {{ app()->version() }}</span>
            <span class="chip">/api</span>
            <span class="chip">Sanctum auth</span>
        </div>

        <footer>
            Backend de <a href="https://domiquibdo.bello.works">domiquibdo.bello.works</a>
            · Proyecto de Electiva 5, UNICLARETIANA
        </footer>
    </div>
</body>
</html>
