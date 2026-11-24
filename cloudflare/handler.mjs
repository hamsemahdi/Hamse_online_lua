export function createHandler({ payload, manifest, primaryName }) {
    return async (request) => {
        const url = new URL(request.url);
        const method = request.method;

        // CORS headers
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, User-Agent',
        };

        if (method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }

        // GET /2.lua ama /{primaryName}
        if (method === 'GET' && (url.pathname === `/${primaryName}` || url.pathname === '/')) {
            return new Response(payload, {
                headers: {
                    ...corsHeaders,
                    'Content-Type': 'text/plain',
                    'Cache-Control': 'no-store'
                }
            });
        }

        // GET /health
        if (method === 'GET' && url.pathname === '/health') {
            return new Response(JSON.stringify({ status: 'ok', version: manifest.version }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        // POST /
        if (method === 'POST' && url.pathname === '/') {
            try {
                const contentType = request.headers.get('Content-Type') || '';
                if (!contentType.includes('application/x-www-form-urlencoded')) {
                    return new Response('Invalid Content-Type', { status: 400, headers: corsHeaders });
                }

                const text = await request.text();
                const params = new URLSearchParams(text);
                
                if (params.get('key_path') === primaryName) {
                    return new Response(payload, {
                        headers: {
                            ...corsHeaders,
                            'Content-Type': 'text/plain',
                            'Cache-Control': 'no-store'
                        }
                    });
                }
                return new Response('Invalid key_path', { status: 403, headers: corsHeaders });
            } catch (e) {
                return new Response('Internal Error', { status: 500, headers: corsHeaders });
            }
        }

        return new Response('Not Found', { status: 404, headers: corsHeaders });
    };
}
