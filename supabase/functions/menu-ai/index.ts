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
    const { prompt, restaurantId, menuId, menuSnapshot } = await req.json()

    if (!prompt || typeof prompt !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Prompt mancante' }),
        { status: 400, headers: corsHeaders },
      )
    }

    const rawCategories = Array.isArray(menuSnapshot?.categories)
      ? menuSnapshot.categories
      : []

    const categories = rawCategories
      .filter(
        (category: unknown): category is Record<string, unknown> =>
          category !== null && typeof category === 'object',
      )
      .map((category) => ({
        id: typeof category.id === 'string' ? category.id : '',
        name: typeof category.name === 'string' ? category.name : '',
        active:
          typeof category.menu_category_active === 'boolean'
            ? category.menu_category_active
            : true,
      }))
      .filter((category) => category.name.length > 0)

    const categoryNameById = new Map(
      categories.map((category) => [category.id, category.name]),
    )

    const rawItems = Array.isArray(menuSnapshot?.items)
      ? menuSnapshot.items
      : []

    const items = rawItems
      .filter(
        (item: unknown): item is Record<string, unknown> =>
          item !== null && typeof item === 'object',
      )
      .map((item) => {
        const categoryId =
          typeof item.category_id === 'string' ? item.category_id : ''

        return {
          name: typeof item.name === 'string' ? item.name : '',
          categoryName: categoryNameById.get(categoryId) ?? '',
          description:
            typeof item.description === 'string' ? item.description : '',
          priceCents:
            typeof item.price_cents === 'number' ? item.price_cents : null,
          currency: typeof item.currency === 'string' ? item.currency : 'EUR',
          active:
            typeof item.menu_item_active === 'boolean'
              ? item.menu_item_active
              : true,
          soldOut:
            typeof item.is_sold_out === 'boolean' ? item.is_sold_out : false,
        }
      })
      .filter((item) => item.name.length > 0)

    const menuContext = {
      categories: categories.map((category) => ({
        name: category.name,
        active: category.active,
      })),
      items,
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
      "type": "hide_category",
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
      "type": "hide_item",
      "name": "string",
      "categoryName": "string opzionale"
    }
  ]
}

Regole:
- Se l'utente chiede di aggiungere una categoria, usa "create_category".
- Se l'utente chiede di nascondere, eliminare, rimuovere o cancellare una categoria dal menu, usa "hide_category".
- Se l'utente chiede di aggiungere un piatto, usa "create_item".
- Se l'utente chiede di nascondere, eliminare, rimuovere o cancellare un piatto dal menu, usa "hide_item".
- Le azioni "hide_category" e "hide_item" nascondono dal menu: non cancellano definitivamente nessun dato.
- Nella reply e nel summary usa espressioni come "nascondere dal menu", mai "eliminare definitivamente".
- Il messaggio utente contiene "menuCorrente": consideralo la fonte attendibile sul menu reale del ristorante.
- Controlla il menu corrente prima di produrre qualsiasi azione.
- Considera anche categorie e piatti con active: false: esistono ancora, ma sono nascosti.
- Non creare una categoria o un piatto se ne esiste già uno con lo stesso nome, anche se è nascosto.
- Per nascondere una categoria o un piatto, usa esattamente il nome presente nel menu corrente.
- Se la categoria o il piatto richiesto non esiste, non inventarlo e restituisci actions: [].
- Se la categoria o il piatto è già nascosto, restituisci actions: [] e spiegalo nella reply.
- Se l'utente fa una domanda o saluta senza chiedere modifiche, restituisci actions: [].
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
            `menuCorrente: ${JSON.stringify(menuContext)}\n` +
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