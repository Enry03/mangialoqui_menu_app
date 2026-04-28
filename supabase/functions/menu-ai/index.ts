import OpenAI from 'npm:openai'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: corsHeaders },
    )
  }

  try {
    const { prompt, restaurantId, menuId } = await req.json()

    if (!prompt || typeof prompt !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Prompt mancante' }),
        { status: 400, headers: corsHeaders },
      )
    }

    const apiKey = Deno.env.get('OPENAI_API_KEY')

    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'OPENAI_API_KEY non configurata' }),
        { status: 500, headers: corsHeaders },
      )
    }

    const openai = new OpenAI({ apiKey })

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content: `
Sei un assistente per la gestione del menu di un ristorante.

Rispondi SEMPRE con un JSON valido.
NON restituire testo fuori dal JSON.

Formato obbligatorio:
{
  "reply": "string",
  "summary": "string",
  "actions": [
    {
      "type": "create_category",
      "name": "string"
    },
    {
      "type": "delete_category",
      "name": "string"
    },
    {
      "type": "create_item",
      "name": "string",
      "categoryName": "string",
      "description": "string opzionale",
      "priceCents": 1200,
      "currency": "EUR"
    },
    {
      "type": "delete_item",
      "name": "string",
      "categoryName": "string opzionale"
    }
  ]
}

Regole:
- Se l'utente chiede di aggiungere una categoria, usa "create_category".
- Se l'utente chiede di eliminare/rimuovere/cancellare una categoria, usa "delete_category".
- Se l'utente chiede di aggiungere un piatto, usa "create_item".
- Se l'utente chiede di eliminare/rimuovere/cancellare un piatto, usa "delete_item".
- Se il nome della categoria o del piatto non è chiaro, non inventare: restituisci actions: [].
- "priceCents" deve essere un intero in centesimi.
- "currency" deve essere "EUR" se non specificato.
- reply e summary devono descrivere cosa verrà fatto, non fingere che il database sia già stato aggiornato.
- Non inventare campi extra.
          `.trim(),
        },
        {
          role: 'user',
          content:
            `restaurantId: ${restaurantId ?? ''}\n` +
            `menuId: ${menuId ?? ''}\n` +
            `richiesta: ${prompt}`,
        },
      ],
      temperature: 0.2,
    })

    const content = completion.choices[0]?.message?.content ?? '{}'
    const parsed = JSON.parse(content)

    const reply =
      typeof parsed.reply === 'string'
        ? parsed.reply
        : 'Ho elaborato la richiesta.'

    const summary =
      typeof parsed.summary === 'string'
        ? parsed.summary
        : 'Modifica menu'

    const actions = Array.isArray(parsed.actions)
      ? parsed.actions.filter((item: unknown) => {
          if (!item || typeof item !== 'object') return false
          const action = item as Record<string, unknown>
          return typeof action.type === 'string'
        })
      : []

    return new Response(
      JSON.stringify({
        reply,
        summary,
        actions,
      }),
      { status: 200, headers: corsHeaders },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Errore sconosciuto',
      }),
      { status: 500, headers: corsHeaders },
    )
  }
})