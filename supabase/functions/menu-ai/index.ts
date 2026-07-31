import OpenAI from 'npm:openai'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
}

const maxMenuContextCharacters = 60_000

function normalizeText(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
}

function includesWholeNormalizedText(container: string, value: string) {
  if (!value) return false
  return ` ${container} `.includes(` ${value} `)
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

    const categoryActiveById = new Map(
      categories.map((category) => [category.id, category.active]),
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
          categoryActive: categoryActiveById.get(categoryId) ?? true,
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
        status: category.active ? 'VISIBLE' : 'HIDDEN',
      })),
      items: items.map((item) => ({
        ...item,
        status:
          item.active && item.categoryActive
            ? 'VISIBLE'
            : 'HIDDEN',
      })),
    }

    const serializedMenuContext = JSON.stringify(menuContext)

    if (serializedMenuContext.length > maxMenuContextCharacters) {
      return new Response(
        JSON.stringify({
          error:
            `Menu troppo grande: massimo ${maxMenuContextCharacters} caratteri`,
        }),
        { status: 413, headers: corsHeaders },
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
      "type": "hide_category",
      "name": "string"
    },
    {
      "type": "reactivate_category",
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
    },
    {
      "type": "reactivate_item",
      "name": "string",
      "categoryName": "string opzionale"
    }
  ]
}

Regole:
- Se l'utente chiede di aggiungere una categoria, usa "create_category".
- Se l'utente chiede di nascondere, eliminare, rimuovere o cancellare una categoria dal menu, usa "hide_category".
- Se l'utente chiede di riattivare, ripristinare o rendere nuovamente visibile una categoria nascosta, usa "reactivate_category".
- Se l'utente chiede di aggiungere un piatto, usa "create_item".
- Se l'utente chiede di nascondere, eliminare, rimuovere o cancellare un piatto dal menu, usa "hide_item".
- Se l'utente chiede di riattivare, rendere nuovamente visibile o ripristinare un piatto nascosto, usa "reactivate_item".
- Le azioni "hide_category" e "hide_item" nascondono dal menu: non cancellano definitivamente nessun dato.
- L'azione "reactivate_category" rende nuovamente attiva e visibile una categoria nascosta.
- L'azione "reactivate_item" rende nuovamente attivo il piatto, senza modificare il suo stato soldOut.
- Se un piatto è attivo ma la sua categoria è nascosta, il piatto non è realmente visibile.
- Per rendere visibile un piatto dentro una categoria nascosta, riattiva anche la categoria.
- Nella reply e nel summary usa espressioni come "nascondere dal menu", mai "eliminare definitivamente".
- Il messaggio utente contiene "menuCorrente": consideralo la fonte attendibile sul menu reale del ristorante.
- Controlla SEMPRE il menu corrente prima di produrre qualsiasi azione.
- Lo stato degli elementi è esplicito e NON deve essere interpretato liberamente:
  - active: true e status: "VISIBLE" significano che l'elemento è ATTIVO e VISIBILE.
  - active: false e status: "HIDDEN" significano che l'elemento è DISATTIVATO e NASCOSTO.
- NON dichiarare mai che un elemento è "già nascosto" se nel menuCorrente ha active: true o status: "VISIBLE".
- Se l'utente chiede di nascondere un elemento con active: true / status: "VISIBLE", devi produrre la relativa azione hide_category o hide_item.
- Solo un elemento con active: false / status: "HIDDEN" deve essere considerato già nascosto.
- is_sold_out / soldOut NON significa nascosto: indica soltanto indisponibilità temporanea ed è indipendente da active.
- Considera anche categorie e piatti con active: false: esistono ancora, ma sono nascosti.
- Non creare una categoria o un piatto se ne esiste già uno con lo stesso nome, anche se è nascosto.
- Per nascondere una categoria o un piatto, usa esattamente il nome presente nel menu corrente.
- Se la categoria o il piatto richiesto non esiste, non inventarlo e restituisci actions: [].
- Se l'utente chiede di nascondere una categoria o un piatto già nascosto, cioè active: false / status: "HIDDEN", restituisci actions: [] e spiegalo nella reply.
- Se l'utente chiede di riattivare una categoria, produci "reactivate_category" solo se la categoria ha active: false / status: "HIDDEN".
- Se l'utente chiede di riattivare una categoria già attiva, restituisci actions: [] e spiegalo nella reply.
- Se l'utente chiede di riattivare un piatto con active: false, usa "reactivate_item".
- Se il piatto appartiene a una categoria con categoryActive: false, usa anche "reactivate_category".
- Se il piatto è attivo ma la sua categoria è nascosta, riattiva soltanto la categoria.
- Se il piatto e la sua categoria sono già attivi, restituisci actions: [] e spiegalo nella reply.
- Per riattivare una categoria o un piatto, usa esattamente il nome presente nel menu corrente.
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
            `menuCorrente: ${serializedMenuContext}\n` +
            `richiesta: ${prompt}`,
        },
      ],
      temperature: 0,
      max_completion_tokens: 300,
    })

    const content = completion.choices[0]?.message?.content ?? '{}'
    const parsed = JSON.parse(content)

    let reply =
      typeof parsed.reply === 'string'
        ? parsed.reply
        : 'Ho elaborato la richiesta.'

    let summary =
      typeof parsed.summary === 'string'
        ? parsed.summary
        : 'Modifica menu'

    const rawActions: Record<string, unknown>[] = Array.isArray(parsed.actions)
      ? parsed.actions.filter(
          (item: unknown): item is Record<string, unknown> => {
            if (!item || typeof item !== 'object') return false

            const action = item as Record<string, unknown>
            return typeof action.type === 'string'
          },
        )
      : []

    const resolveCategoriesForAction = (
      action: Record<string, unknown>,
    ) => {
      const actionName =
        typeof action.name === 'string' ? normalizeText(action.name) : ''

      if (!actionName) {
        return []
      }

      return categories.filter(
        (category) => normalizeText(category.name) === actionName,
      )
    }

    const resolveItemsForAction = (action: Record<string, unknown>) => {
      const actionName =
        typeof action.name === 'string' ? normalizeText(action.name) : ''

      const actionCategoryName =
        typeof action.categoryName === 'string'
          ? normalizeText(action.categoryName)
          : ''

      if (!actionName) {
        return []
      }

      return items.filter((item) => {
        if (normalizeText(item.name) !== actionName) {
          return false
        }

        if (
          actionCategoryName &&
          normalizeText(item.categoryName) !== actionCategoryName
        ) {
          return false
        }

        return true
      })
    }

    const allowedActionTypes = new Set([
      'create_category',
      'hide_category',
      'reactivate_category',
      'create_item',
      'hide_item',
      'reactivate_item',
    ])

    let actions: Record<string, unknown>[] = []

    const pushUniqueAction = (action: Record<string, unknown>) => {
      const key = [
        String(action.type ?? ''),
        normalizeText(String(action.name ?? '')),
        normalizeText(String(action.categoryName ?? '')),
      ].join('|')

      const alreadyPresent = actions.some((currentAction) => {
        const currentKey = [
          String(currentAction.type ?? ''),
          normalizeText(String(currentAction.name ?? '')),
          normalizeText(String(currentAction.categoryName ?? '')),
        ].join('|')

        return currentKey === key
      })

      if (!alreadyPresent) {
        actions.push(action)
      }
    }

    const ensureCategoryReactivation = (categoryName: string) => {
      const matchingCategories = categories.filter(
        (category) =>
          normalizeText(category.name) === normalizeText(categoryName),
      )

      if (
        matchingCategories.length === 1 &&
        !matchingCategories[0].active
      ) {
        pushUniqueAction({
          type: 'reactivate_category',
          name: matchingCategories[0].name,
        })
      }
    }

    for (const action of rawActions) {
      const type =
        typeof action.type === 'string' ? action.type : ''

      if (!allowedActionTypes.has(type)) {
        continue
      }

      if (
        type === 'hide_category' ||
        type === 'reactivate_category'
      ) {
        const matchingCategories = resolveCategoriesForAction(action)

        if (matchingCategories.length !== 1) {
          continue
        }

        const matchingCategory = matchingCategories[0]

        if (type === 'hide_category' && matchingCategory.active) {
          pushUniqueAction({
            type: 'hide_category',
            name: matchingCategory.name,
          })
        }

        if (
          type === 'reactivate_category' &&
          !matchingCategory.active
        ) {
          pushUniqueAction({
            type: 'reactivate_category',
            name: matchingCategory.name,
          })
        }

        continue
      }

      if (type === 'hide_item' || type === 'reactivate_item') {
        const matchingItems = resolveItemsForAction(action)

        if (matchingItems.length !== 1) {
          continue
        }

        const matchingItem = matchingItems[0]

        if (type === 'hide_item') {
          if (matchingItem.active) {
            pushUniqueAction({
              type: 'hide_item',
              name: matchingItem.name,
              ...(matchingItem.categoryName
                ? { categoryName: matchingItem.categoryName }
                : {}),
            })
          }

          continue
        }

        if (!matchingItem.categoryActive) {
          ensureCategoryReactivation(matchingItem.categoryName)
        }

        if (!matchingItem.active) {
          pushUniqueAction({
            type: 'reactivate_item',
            name: matchingItem.name,
            ...(matchingItem.categoryName
              ? { categoryName: matchingItem.categoryName }
              : {}),
          })
        }

        continue
      }

      pushUniqueAction(action)
    }

    const normalizedPrompt = normalizeText(prompt)

    const reactivateIntent =
      /\b(riattiv\w*|riabilit\w*|ripristin\w*|riaccend\w*|rimett\w*|attiv\w*)\b/
        .test(normalizedPrompt) ||
      /\bmostr\w*\s+di\s+nuovo\b/.test(normalizedPrompt) ||
      /\brend\w*\s+(di\s+nuovo\s+)?visibil\w*\b/
        .test(normalizedPrompt)

    const hideIntent =
      /\b(nascond\w*|disattiv\w*|rimuov\w*|elimin\w*|cancell\w*|togli\w*)\b/
        .test(normalizedPrompt)

    const mentionsCategoryWord =
      /\bcategori\w*\b/.test(normalizedPrompt)

    const mentionsItemWord =
      /\b(piatt\w*|prodott\w*|portat\w*)\b/.test(normalizedPrompt)

    const keepLongestNameMatches = <T extends { name: string }>(
      matches: T[],
    ) => {
      if (matches.length <= 1) {
        return matches
      }

      const longestLength = Math.max(
        ...matches.map((match) => normalizeText(match.name).length),
      )

      return matches.filter(
        (match) => normalizeText(match.name).length === longestLength,
      )
    }

    let promptCategoryMatches = keepLongestNameMatches(
      categories.filter((category) =>
        includesWholeNormalizedText(
          normalizedPrompt,
          normalizeText(category.name),
        ),
      ),
    )

    let promptItemMatches = keepLongestNameMatches(
      items.filter((item) =>
        includesWholeNormalizedText(
          normalizedPrompt,
          normalizeText(item.name),
        ),
      ),
    )

    if (
      promptItemMatches.length > 1 &&
      promptCategoryMatches.length === 1
    ) {
      const categoryName = normalizeText(
        promptCategoryMatches[0].name,
      )

      const qualifiedItems = promptItemMatches.filter(
        (item) =>
          normalizeText(item.categoryName) === categoryName,
      )

      if (qualifiedItems.length > 0) {
        promptItemMatches = qualifiedItems
      }
    }

    const itemQualifiedByCategory =
      promptItemMatches.length === 1 &&
      promptCategoryMatches.length === 1 &&
      normalizeText(promptItemMatches[0].categoryName) ===
        normalizeText(promptCategoryMatches[0].name) &&
      normalizeText(promptItemMatches[0].name) !==
        normalizeText(promptCategoryMatches[0].name)

    let targetType: 'category' | 'item' | null = null

    if (mentionsItemWord && promptItemMatches.length === 1) {
      targetType = 'item'
    } else if (itemQualifiedByCategory) {
      targetType = 'item'
    } else if (
      mentionsCategoryWord &&
      promptCategoryMatches.length === 1 &&
      promptItemMatches.length === 0
    ) {
      targetType = 'category'
    } else if (
      promptItemMatches.length === 1 &&
      promptCategoryMatches.length === 0
    ) {
      targetType = 'item'
    } else if (
      promptCategoryMatches.length === 1 &&
      promptItemMatches.length === 0
    ) {
      targetType = 'category'
    } else if (
      mentionsCategoryWord &&
      !mentionsItemWord &&
      promptCategoryMatches.length === 1
    ) {
      targetType = 'category'
    }

    if (reactivateIntent !== hideIntent) {
      if (targetType === 'category') {
        const matchingCategory = promptCategoryMatches[0]

        actions = []

        if (reactivateIntent) {
          if (matchingCategory.active) {
            reply =
              `La categoria '${matchingCategory.name}' è già attiva e visibile.`
            summary =
              `Nessuna modifica: '${matchingCategory.name}' è già attiva.`
          } else {
            actions = [
              {
                type: 'reactivate_category',
                name: matchingCategory.name,
              },
            ]
            reply =
              `Riattiverò la categoria '${matchingCategory.name}'.`
            summary =
              `Riattivazione della categoria '${matchingCategory.name}'.`
          }
        } else {
          if (matchingCategory.active) {
            actions = [
              {
                type: 'hide_category',
                name: matchingCategory.name,
              },
            ]
            reply =
              `Nasconderò la categoria '${matchingCategory.name}' dal menu.`
            summary =
              `La categoria '${matchingCategory.name}' verrà nascosta.`
          } else {
            reply =
              `La categoria '${matchingCategory.name}' è già nascosta.`
            summary =
              `Nessuna modifica: '${matchingCategory.name}' è già nascosta.`
          }
        }
      } else if (targetType === 'item') {
        const matchingItem = promptItemMatches[0]

        actions = []

        if (reactivateIntent) {
          if (!matchingItem.categoryActive) {
            actions.push({
              type: 'reactivate_category',
              name: matchingItem.categoryName,
            })
          }

          if (!matchingItem.active) {
            actions.push({
              type: 'reactivate_item',
              name: matchingItem.name,
              ...(matchingItem.categoryName
                ? { categoryName: matchingItem.categoryName }
                : {}),
            })
          }

          if (actions.length === 0) {
            reply =
              `Il piatto '${matchingItem.name}' è già attivo e visibile nel menu.`
            summary =
              `Nessuna modifica: '${matchingItem.name}' è già attivo.`
          } else if (
            !matchingItem.categoryActive &&
            !matchingItem.active
          ) {
            reply =
              `Riattiverò la categoria '${matchingItem.categoryName}' e il piatto '${matchingItem.name}'.`
            summary =
              `Riattivazione della categoria '${matchingItem.categoryName}' e del piatto '${matchingItem.name}'.`
          } else if (!matchingItem.categoryActive) {
            reply =
              `Il piatto '${matchingItem.name}' è già attivo: riattiverò la categoria '${matchingItem.categoryName}' per renderlo visibile.`
            summary =
              `Riattivazione della categoria '${matchingItem.categoryName}'.`
          } else {
            reply =
              `Riattiverò il piatto '${matchingItem.name}'.`
            summary =
              `Riattivazione del piatto '${matchingItem.name}'.`
          }
        } else {
          if (matchingItem.active) {
            actions = [
              {
                type: 'hide_item',
                name: matchingItem.name,
                ...(matchingItem.categoryName
                  ? { categoryName: matchingItem.categoryName }
                  : {}),
              },
            ]
            reply =
              `Nasconderò il piatto '${matchingItem.name}' dal menu.`
            summary =
              `Il piatto '${matchingItem.name}' verrà nascosto dal menu.`
          } else {
            reply =
              `Il piatto '${matchingItem.name}' è già nascosto dal menu.`
            summary =
              `Nessuna modifica: '${matchingItem.name}' è già nascosto.`
          }
        }
      } else if (
        promptCategoryMatches.length > 0 ||
        promptItemMatches.length > 0
      ) {
        actions = []
        reply =
          'La richiesta è ambigua: specifica chiaramente se vuoi modificare una categoria oppure un piatto.'
        summary = 'Nessuna modifica: elemento ambiguo.'
      }
    }

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