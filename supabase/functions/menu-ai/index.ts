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

function findWholeNameOccurrences(container: string, value: string) {
  const occurrences: { start: number; end: number }[] = []

  if (!value) {
    return occurrences
  }

  let searchFrom = 0

  while (searchFrom <= container.length - value.length) {
    const start = container.indexOf(value, searchFrom)

    if (start < 0) {
      break
    }

    const end = start + value.length
    const startsAtWordBoundary = start === 0 || container[start - 1] === ' '
    const endsAtWordBoundary =
      end === container.length || container[end] === ' '

    if (startsAtWordBoundary && endsAtWordBoundary) {
      occurrences.push({ start, end })
    }

    searchFrom = start + 1
  }

  return occurrences
}

function orderReactivationActions(actions: Record<string, unknown>[]) {
  const firstItemIndex = actions.findIndex(
    (action) => action.type === 'reactivate_item',
  )

  if (firstItemIndex < 0) {
    return actions
  }

  const categoriesToMove = actions
    .slice(firstItemIndex + 1)
    .filter((action) => action.type === 'reactivate_category')

  if (categoriesToMove.length === 0) {
    return actions
  }

  const categoriesToMoveSet = new Set(categoriesToMove)
  const orderedActions = actions.filter(
    (action) => !categoriesToMoveSet.has(action),
  )
  const insertionIndex = orderedActions.findIndex(
    (action) => action.type === 'reactivate_item',
  )

  orderedActions.splice(insertionIndex, 0, ...categoriesToMove)
  return orderedActions
}

function joinItalianList(parts: string[]) {
  if (parts.length <= 1) {
    return parts[0] ?? ''
  }

  if (parts.length === 2) {
    return `${parts[0]} e ${parts[1]}`
  }

  return `${parts.slice(0, -1).join(', ')} e ${parts.at(-1)}`
}

function formatQuotedNames(names: string[]) {
  return joinItalianList(names.map((name) => `'${name}'`))
}

function describeActionTargets(actions: Record<string, unknown>[]) {
  const groups: Record<string, unknown>[][] = []

  for (const action of actions) {
    const currentGroup = groups.at(-1)

    if (
      currentGroup &&
      currentGroup[0]?.type === action.type
    ) {
      currentGroup.push(action)
    } else {
      groups.push([action])
    }
  }

  const parts = groups.map((group) => {
    const isCategory = String(group[0]?.type ?? '').endsWith('_category')
    const targets = group.map((action) => {
      const name = String(action.name ?? '')

      if (isCategory) {
        return `'${name}'`
      }

      const categoryName =
        typeof action.categoryName === 'string'
          ? action.categoryName
          : ''

      return categoryName
        ? `'${name}' della categoria '${categoryName}'`
        : `'${name}'`
    })
    const label = isCategory
      ? targets.length === 1
        ? 'la categoria'
        : 'le categorie'
      : targets.length === 1
        ? 'il piatto'
        : 'i piatti'

    return `${label} ${joinItalianList(targets)}`
  })

  return joinItalianList(parts)
}

function describeVisibilityActions(actions: Record<string, unknown>[]) {
  const hideActions = actions.filter(
    (action) => action.type === 'hide_category' || action.type === 'hide_item',
  )
  const reactivateActions = actions.filter(
    (action) =>
      action.type === 'reactivate_category' ||
      action.type === 'reactivate_item',
  )
  const sentences: { index: number; text: string }[] = []

  if (hideActions.length > 0) {
    sentences.push({
      index: actions.findIndex(
        (action) =>
          action.type === 'hide_category' || action.type === 'hide_item',
      ),
      text: `Nasconderò ${describeActionTargets(hideActions)} dal menu.`,
    })
  }

  if (reactivateActions.length > 0) {
    sentences.push({
      index: actions.findIndex(
        (action) =>
          action.type === 'reactivate_category' ||
          action.type === 'reactivate_item',
      ),
      text: `Riattiverò ${describeActionTargets(reactivateActions)}.`,
    })
  }

  return sentences
    .sort((left, right) => left.index - right.index)
    .map((sentence) => sentence.text)
    .join(' ')
}

function isMenuMutationRequest(value: string) {
  const normalized = normalizeText(value)

  const hasUnambiguousMutationVerb =
    /\b(?:aggiung\w*|crea\w*|inserisc\w*|nascond\w*|disattiv\w*|elimin\w*|rimuov\w*|cancell\w*|togl\w*|riattiv\w*|riabilit\w*|ripristin\w*|riaccend\w*|rimett\w*)\b/
      .test(normalized)

  const hasActivationCommand =
    /^(?:(?:per favore|gentilmente|puoi|potresti|vorrei|voglio|devo)\s+)*(?:attiva(?:lo|la|li|le)?|attivare|attivarlo|attivarla|attivarli|attivarle)\b/
      .test(normalized) ||
    /\bmi\s+attivi\b/.test(normalized)

  return (
    hasUnambiguousMutationVerb ||
    hasActivationCommand ||
    normalized.includes('mostra di nuovo') ||
    normalized.includes('mostrare di nuovo') ||
    normalized.includes('rendi di nuovo disponibile') ||
    normalized.includes('rendere di nuovo disponibile') ||
    normalized.includes('rendi nuovamente visibile') ||
    normalized.includes('rendere nuovamente visibile')
  )
}

function describeVerifiedMenuActions(
  actions: Record<string, unknown>[],
) {
  return actions
    .map((action) => {
      const type = String(action.type ?? '')
      const name = String(action.name ?? '').trim()
      const categoryName = String(action.categoryName ?? '').trim()

      if (!name) {
        return ''
      }

      if (type === 'create_category') {
        return `Creerò la categoria '${name}'.`
      }

      if (type === 'hide_category') {
        return `Nasconderò la categoria '${name}' dal menu.`
      }

      if (type === 'reactivate_category') {
        return `Riattiverò la categoria '${name}'.`
      }

      if (type === 'create_item') {
        return categoryName
          ? `Aggiungerò il piatto '${name}' nella categoria '${categoryName}'.`
          : `Aggiungerò il piatto '${name}'.`
      }

      if (type === 'hide_item') {
        return categoryName
          ? `Nasconderò il piatto '${name}' della categoria '${categoryName}' dal menu.`
          : `Nasconderò il piatto '${name}' dal menu.`
      }

      if (type === 'reactivate_item') {
        return categoryName
          ? `Riattiverò il piatto '${name}' della categoria '${categoryName}'.`
          : `Riattiverò il piatto '${name}'.`
      }

      return ''
    })
    .filter((part) => part.length > 0)
    .join(' ')
}

function formatPriceCents(priceCents: number | null) {
  if (
    priceCents === null ||
    !Number.isInteger(priceCents) ||
    priceCents < 0
  ) {
    return 'prezzo non disponibile'
  }

  return new Intl.NumberFormat('it-IT', {
    style: 'currency',
    currency: 'EUR',
  }).format(priceCents / 100)
}

type CreateItemDraft = {
  name: string
  categoryName: string
  priceCents: number | null
}

function parseEuroPriceToCents(value: string) {
  const match = value.match(
    /(\d+(?:[.,]\d{1,2})?)\s*(?:€|euro)/i,
  )

  if (!match) {
    return null
  }

  const amount = Number(match[1].replace(',', '.'))

  if (!Number.isFinite(amount) || amount <= 0) {
    return null
  }

  return Math.round(amount * 100)
}

function splitTrailingEuroPrice(value: string) {
  const match = value.match(
    /^(.*?)(?:\s+(?:a|al\s+prezzo\s+di|con\s+prezzo\s+di|costa)\s+(\d+(?:[.,]\d{1,2})?)\s*(?:€|euro))\s*$/i,
  )

  if (!match) {
    return {
      text: value.trim(),
      priceCents: null,
    }
  }

  const amount = Number(match[2].replace(',', '.'))

  return {
    text: match[1].trim(),
    priceCents:
      Number.isFinite(amount) && amount > 0
        ? Math.round(amount * 100)
        : null,
  }
}

function parseCreateItemDraft(value: string): CreateItemDraft | null {
  const guidedMatch = value.match(
    /^\s*aggiungi\s+un\s+piatto\s+nella\s+categoria\s+(.+?)\s*:\s*(.*?)\s*$/i,
  )

  if (guidedMatch) {
    const parsedItem = splitTrailingEuroPrice(guidedMatch[2])
    const categoryName = guidedMatch[1].trim()

    if (!parsedItem.text || !categoryName) {
      return null
    }

    return {
      name: parsedItem.text,
      categoryName,
      priceCents: parsedItem.priceCents,
    }
  }

  const naturalMatch = value.match(
    /^\s*aggiungi\s+(.+?)\s+nella\s+categoria\s+(.+?)\s*$/i,
  )

  if (!naturalMatch) {
    return null
  }

  const name = naturalMatch[1]
    .replace(/^(?:un\s+piatto(?:\s+chiamato)?)\s*/i, '')
    .trim()
  const parsedCategory = splitTrailingEuroPrice(naturalMatch[2])

  if (!name || !parsedCategory.text) {
    return null
  }

  return {
    name,
    categoryName: parsedCategory.text,
    priceCents: parsedCategory.priceCents,
  }
}

function isCancellationPrompt(value: string) {
  const normalized = normalizeText(value)

  return /^(?:no\s+)?(?:annulla(?:\s+(?:tutto|la modifica|l operazione|operazione))?|annullalo|lascia\s+(?:perdere|stare)|non\s+(?:procedere|farlo|aggiungerlo|aggiungerla)|ferma\s+tutto|stop)$/
    .test(normalized)
}

function parseStandaloneEuroPriceToCents(value: string) {
  const match = value.match(
    /^\s*(\d+(?:[.,]\d{1,2})?)\s*(?:€|euro)\s*$/i,
  )

  if (!match) {
    return null
  }

  const amount = Number(match[1].replace(',', '.'))

  if (!Number.isFinite(amount) || amount <= 0) {
    return null
  }

  return Math.round(amount * 100)
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
    const {
      prompt,
      restaurantId,
      menuId,
      menuSnapshot,
      conversationContext,
    } = await req.json()

    if (!prompt || typeof prompt !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Prompt mancante' }),
        { status: 400, headers: corsHeaders },
      )
    }

    type ConversationMessage = {
      role: 'user' | 'assistant'
      content: string
    }

    const rawConversationContext = Array.isArray(conversationContext)
      ? conversationContext
      : []

    const sanitizedConversationContext: ConversationMessage[] = []
    let remainingConversationCharacters = 6000

    for (const rawMessage of rawConversationContext.slice(-8).reverse()) {
      if (remainingConversationCharacters <= 0) {
        break
      }

      if (
        rawMessage === null ||
        typeof rawMessage !== 'object'
      ) {
        continue
      }

      const message = rawMessage as Record<string, unknown>
      const role = message.role

      if (role !== 'user' && role !== 'assistant') {
        continue
      }

      if (typeof message.content !== 'string') {
        continue
      }

      let content = message.content.trim()

      if (!content) {
        continue
      }

      if (content.length > 1000) {
        content = content.slice(0, 1000)
      }

      if (content.length > remainingConversationCharacters) {
        content = content.slice(0, remainingConversationCharacters)
      }

      sanitizedConversationContext.unshift({
        role,
        content,
      })

      remainingConversationCharacters -= content.length
    }

    let effectiveConversationContext = [
      ...sanitizedConversationContext,
    ]
    let lastCancellationIndex = -1

    for (
      let index = 0;
      index < sanitizedConversationContext.length;
      index += 1
    ) {
      const message = sanitizedConversationContext[index]

      if (
        message.role === 'user' &&
        isCancellationPrompt(message.content)
      ) {
        lastCancellationIndex = index
      }
    }

    if (lastCancellationIndex >= 0) {
      effectiveConversationContext =
        sanitizedConversationContext.slice(lastCancellationIndex + 1)

      while (effectiveConversationContext[0]?.role === 'assistant') {
        effectiveConversationContext =
          effectiveConversationContext.slice(1)
      }
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

    const normalizedPrompt = normalizeText(prompt)
    const menuMutationRequest = isMenuMutationRequest(prompt)

    if (isCancellationPrompt(prompt)) {
      return new Response(
        JSON.stringify({
          reply: 'Operazione annullata. Non applicherò modifiche al menu.',
          summary: 'Operazione annullata.',
          actions: [],
        }),
        { status: 200, headers: corsHeaders },
      )
    }

    const containsMenuEntity = (value: string) => {
      const normalizedValue = normalizeText(value)

      return (
        categories.some(
          (category) =>
            findWholeNameOccurrences(
              normalizedValue,
              normalizeText(category.name),
            ).length > 0,
        ) ||
        items.some(
          (item) =>
            findWholeNameOccurrences(
              normalizedValue,
              normalizeText(item.name),
            ).length > 0,
        )
      )
    }

    const menuInformationKeywords =
      /\b(?:menu|piatto|piatti|categoria|categorie|prezzo|prezzi|costa|costano|quanto|disponibile|disponibili|indisponibile|indisponibili|attivo|attiva|attivi|attive|visibile|visibili|nascosto|nascosta|nascosti|nascoste|esiste|esistono|contiene|contengono|quali|elenca|mostrami)\b/

    const isExplicitFullMenuListRequest = (value: string) => {
      const normalizedValue = normalizeText(value)

      if (containsMenuEntity(value)) {
        return false
      }

      const requestsListing =
        /\b(?:elenca|elencami|mostra|mostrami|lista|riepiloga)\b/
          .test(normalizedValue) ||
        /\bquali\b.*\bpiatti\b/.test(normalizedValue)

      const targetsWholeMenu =
        normalizedValue.includes('menu') ||
        normalizedValue.includes('tutti i piatti')

      return requestsListing && targetsWholeMenu
    }

    const explicitFullMenuListRequest =
      isExplicitFullMenuListRequest(prompt)

    const repeatPrompt =
      /^(?:di nuovo|rifallo|rifalla|ripeti|ripetilo|ripetila|elenca di nuovo|elencali di nuovo|mostrameli di nuovo|aggiorna l elenco|aggiorna elenco)$/
        .test(normalizedPrompt)

    const latestPreviousUserMessage = [
      ...effectiveConversationContext,
    ]
      .reverse()
      .find((message) => message.role === 'user')

    const previousFullMenuListRequest =
      latestPreviousUserMessage !== undefined &&
      isExplicitFullMenuListRequest(
        latestPreviousUserMessage.content,
      )

    const repeatFullMenuListRequest =
      repeatPrompt && previousFullMenuListRequest

    if (repeatPrompt && !repeatFullMenuListRequest) {
      return new Response(
        JSON.stringify({
          reply:
            'Non ripeto automaticamente una modifica al menu. Specifica cosa vuoi fare di nuovo.',
          summary:
            'Nessuna modifica: richiesta di ripetizione non sufficientemente specifica.',
          actions: [],
        }),
        { status: 200, headers: corsHeaders },
      )
    }

    const menuInformationRequest =
      !menuMutationRequest &&
      (
        explicitFullMenuListRequest ||
        repeatFullMenuListRequest ||
        menuInformationKeywords.test(normalizedPrompt) ||
        containsMenuEntity(prompt)
      )

    const buildFullMenuListReply = () => {
      const categorySections = categories.map((category) => {
        const categoryItems = items.filter(
          (item) =>
            normalizeText(item.categoryName) ===
            normalizeText(category.name),
        )

        const categoryHeader = category.active
          ? category.name
          : `${category.name} — categoria nascosta`

        const itemLines =
          categoryItems.length > 0
            ? categoryItems.map((item) => {
                const statuses: string[] = []

                if (!item.active) {
                  statuses.push('disattivato')
                }

                if (item.soldOut) {
                  statuses.push('esaurito')
                }

                const statusSuffix =
                  statuses.length > 0
                    ? ` (${statuses.join(', ')})`
                    : ''

                return `• ${item.name}${statusSuffix}`
              })
            : ['• Nessun piatto']

        return [
          categoryHeader,
          ...itemLines,
        ].join('\n')
      })

      return categorySections.length > 0
        ? categorySections.join('\n\n')
        : 'Il menu attuale non contiene categorie o piatti.'
    }

    if (menuInformationRequest) {
      let verifiedReply = ''

      if (
        explicitFullMenuListRequest ||
        repeatFullMenuListRequest
      ) {
        verifiedReply = buildFullMenuListReply()
      } else {
        const referenceTexts = [
          prompt,
          ...[...effectiveConversationContext]
            .reverse()
            .filter((message) => message.role === 'user')
            .map((message) => message.content),
        ]

        const referenceText =
          referenceTexts.find((value) => containsMenuEntity(value)) ??
          prompt

        const normalizedReferenceText = normalizeText(referenceText)

        const referencedItems = items.filter(
          (item) =>
            findWholeNameOccurrences(
              normalizedReferenceText,
              normalizeText(item.name),
            ).length > 0,
        )

        const referencedCategories = categories.filter(
          (category) =>
            findWholeNameOccurrences(
              normalizedReferenceText,
              normalizeText(category.name),
            ).length > 0,
        )

        if (referencedItems.length > 0) {
        verifiedReply = referencedItems
          .map((item) => {
            const visibilityStatus = !item.active
              ? 'disattivato e nascosto'
              : !item.categoryActive
                ? `attivo ma non visibile perché la categoria '${item.categoryName}' è nascosta`
                : 'attivo e visibile'

            const availabilityStatus = item.soldOut
              ? 'non disponibile'
              : 'disponibile'

            return (
              `Il piatto '${item.name}' appartiene alla categoria ` +
              `'${item.categoryName}', costa ` +
              `${formatPriceCents(item.priceCents)}, è ` +
              `${visibilityStatus} ed è ${availabilityStatus}.`
            )
          })
          .join(' ')
      } else if (referencedCategories.length > 0) {
        verifiedReply = referencedCategories
          .map((category) => {
            const categoryItems = items.filter(
              (item) =>
                normalizeText(item.categoryName) ===
                normalizeText(category.name),
            )

            const itemList =
              categoryItems.length > 0
                ? categoryItems
                    .map((item) => `'${item.name}'`)
                    .join(', ')
                : 'nessun piatto'

            const categoryStatus = category.active
              ? 'attiva e visibile'
              : 'disattivata e nascosta'

            return (
              `La categoria '${category.name}' è ${categoryStatus} ` +
              `e contiene: ${itemList}.`
            )
          })
          .join(' ')
        } else {
          verifiedReply = buildFullMenuListReply()
        }
      }

      return new Response(
        JSON.stringify({
          reply: verifiedReply,
          summary: 'Informazioni verificate sul menu attuale.',
          actions: [],
        }),
        { status: 200, headers: corsHeaders },
      )
    }

    const collectiveHideItemsMatch = normalizedPrompt.match(
      /^(?:(?:per favore|gentilmente|puoi|potresti)\s+)*(?:nascondi|disattiva|rimuovi|elimina|cancella|togli)\s+(?:tutti|tutte)\s+(.+?)\s+(?:dalla|della|nella|dentro la)\s+categoria\s+(.+)$/,
    )

    if (collectiveHideItemsMatch) {
      const requestedGroupName = collectiveHideItemsMatch[1]
        .replace(/^(?:i|gli|le)\s+/, '')
        .trim()

      const requestedCategoryName =
        collectiveHideItemsMatch[2].trim()

      const matchingCategories = categories.filter(
        (category) =>
          normalizeText(category.name) === requestedCategoryName,
      )

      if (matchingCategories.length === 0) {
        return new Response(
          JSON.stringify({
            reply:
              `La categoria '${requestedCategoryName}' non esiste nel menu attuale.`,
            summary:
              'Nessuna modifica: categoria non trovata.',
            actions: [],
          }),
          { status: 200, headers: corsHeaders },
        )
      }

      if (matchingCategories.length > 1) {
        return new Response(
          JSON.stringify({
            reply:
              `La categoria '${requestedCategoryName}' non è univoca: specifica quale intendi.`,
            summary:
              'Nessuna modifica: categoria non univoca.',
            actions: [],
          }),
          { status: 200, headers: corsHeaders },
        )
      }

      const matchingCategory = matchingCategories[0]
      const normalizedGroupName = normalizeText(requestedGroupName)
      const genericGroupNames = new Set([
        'piatti',
        'prodotti',
        'elementi',
        'portate',
      ])

      const groupMatchesCategory =
        normalizedGroupName ===
        normalizeText(matchingCategory.name)

      if (
        !genericGroupNames.has(normalizedGroupName) &&
        !groupMatchesCategory
      ) {
        return new Response(
          JSON.stringify({
            reply:
              `Non è chiaro se vuoi nascondere tutti i piatti della categoria '${matchingCategory.name}'. Riscrivi, ad esempio: "Nascondi tutti i piatti della categoria ${matchingCategory.name}".`,
            summary:
              'Nessuna modifica: richiesta collettiva da chiarire.',
            actions: [],
          }),
          { status: 200, headers: corsHeaders },
        )
      }

      const categoryItems = items.filter(
        (item) =>
          normalizeText(item.categoryName) ===
          normalizeText(matchingCategory.name),
      )

      if (categoryItems.length === 0) {
        return new Response(
          JSON.stringify({
            reply:
              `La categoria '${matchingCategory.name}' non contiene piatti.`,
            summary:
              'Nessuna modifica: categoria senza piatti.',
            actions: [],
          }),
          { status: 200, headers: corsHeaders },
        )
      }

      const activeCategoryItems = categoryItems.filter(
        (item) => item.active,
      )

      if (activeCategoryItems.length === 0) {
        return new Response(
          JSON.stringify({
            reply:
              `Tutti i piatti della categoria '${matchingCategory.name}' sono già nascosti.`,
            summary:
              'Nessuna modifica: tutti i piatti sono già nascosti.',
            actions: [],
          }),
          { status: 200, headers: corsHeaders },
        )
      }

      return new Response(
        JSON.stringify({
          reply:
            `Nasconderò tutti i piatti della categoria '${matchingCategory.name}' dal menu.`,
          summary:
            `Nascondere tutti i piatti della categoria '${matchingCategory.name}' dal menu.`,
          actions: activeCategoryItems.map((item) => ({
            type: 'hide_item',
            name: item.name,
            categoryName: matchingCategory.name,
          })),
        }),
        { status: 200, headers: corsHeaders },
      )
    }

    let deterministicCreateItemDraft = parseCreateItemDraft(prompt)

    if (deterministicCreateItemDraft === null) {
      const followUpPriceCents = parseEuroPriceToCents(prompt)
      const latestAssistantMessage = [
        ...effectiveConversationContext,
      ]
        .reverse()
        .find((message) => message.role === 'assistant')
      const latestAssistantAskedForPrice =
        latestAssistantMessage !== undefined &&
        normalizeText(latestAssistantMessage.content).includes('prezzo')

      if (
        followUpPriceCents !== null &&
        latestAssistantAskedForPrice
      ) {
        const previousCreateMessage = [
          ...effectiveConversationContext,
        ]
          .reverse()
          .find(
            (message) =>
              message.role === 'user' &&
              parseCreateItemDraft(message.content) !== null,
          )

        const previousCreateDraft = previousCreateMessage
          ? parseCreateItemDraft(previousCreateMessage.content)
          : null

        if (previousCreateDraft !== null) {
          deterministicCreateItemDraft = {
            ...previousCreateDraft,
            priceCents: followUpPriceCents,
          }
        }
      }
    }

    if (
      deterministicCreateItemDraft === null &&
      parseStandaloneEuroPriceToCents(prompt) !== null
    ) {
      return new Response(
        JSON.stringify({
          reply: "Non c'è nessuna aggiunta in sospeso.",
          summary: 'Nessuna modifica: non risultano aggiunte in sospeso.',
          actions: [],
        }),
        { status: 200, headers: corsHeaders },
      )
    }

    if (deterministicCreateItemDraft !== null) {
      const matchingCategories = categories.filter(
        (category) =>
          normalizeText(category.name) ===
          normalizeText(
            deterministicCreateItemDraft!.categoryName,
          ),
      )

      if (matchingCategories.length === 1) {
        const matchingCategory = matchingCategories[0]
        const matchingItems = items.filter(
          (item) =>
            normalizeText(item.name) ===
              normalizeText(deterministicCreateItemDraft!.name) &&
            normalizeText(item.categoryName) ===
              normalizeText(matchingCategory.name),
        )

        if (matchingItems.length > 0) {
          return new Response(
            JSON.stringify({
              reply:
                `Il piatto '${matchingItems[0].name}' esiste già nella categoria '${matchingCategory.name}'.`,
              summary:
                'Nessuna modifica: il piatto esiste già nella categoria indicata.',
              actions: [],
            }),
            { status: 200, headers: corsHeaders },
          )
        }

        if (!matchingCategory.active) {
          return new Response(
            JSON.stringify({
              reply:
                `La categoria '${matchingCategory.name}' è nascosta. Riattivala prima di aggiungere il piatto.`,
              summary:
                'Nessuna modifica: la categoria indicata è nascosta.',
              actions: [],
            }),
            { status: 200, headers: corsHeaders },
          )
        }

        if (deterministicCreateItemDraft.priceCents === null) {
          return new Response(
            JSON.stringify({
              reply:
                `Qual è il prezzo di '${deterministicCreateItemDraft.name}'?`,
              summary:
                'Informazione mancante: prezzo del piatto.',
              actions: [],
            }),
            { status: 200, headers: corsHeaders },
          )
        }

        return new Response(
          JSON.stringify({
            reply:
              `Aggiungerò '${deterministicCreateItemDraft.name}' nella categoria '${matchingCategory.name}'.`,
            summary:
              `Aggiunta del piatto '${deterministicCreateItemDraft.name}' nella categoria '${matchingCategory.name}'.`,
            actions: [
              {
                type: 'create_item',
                name: deterministicCreateItemDraft.name,
                categoryName: matchingCategory.name,
                description: null,
                priceCents:
                  deterministicCreateItemDraft.priceCents,
                currency: 'EUR',
              },
            ],
          }),
          { status: 200, headers: corsHeaders },
        )
      }
    }

    type Category = (typeof categories)[number]
    type Item = (typeof items)[number]
    type VisibilityIntent = 'hide' | 'reactivate'
    type TargetQualifier = 'category' | 'item'
    type IntentMarker = {
      type: VisibilityIntent
      start: number
      end: number
    }
    type QualifierMarker = {
      type: TargetQualifier
      start: number
      end: number
    }
    type NameOccurrence = {
      normalizedName: string
      start: number
      end: number
      categories: Category[]
      items: Item[]
    }
    type TargetDraft = {
      occurrence: NameOccurrence
      targetType: TargetQualifier | null
    }
    type ResolvedTarget =
      | {
          targetType: 'category'
          intent: VisibilityIntent
          start: number
          category: Category
        }
      | {
          targetType: 'item'
          intent: VisibilityIntent
          start: number
          item: Item
        }

    const intentMarkers: IntentMarker[] = []

    const collectIntentMarkers = (
      pattern: RegExp,
      type: VisibilityIntent,
    ) => {
      for (const match of normalizedPrompt.matchAll(pattern)) {
        const start = match.index ?? 0
        intentMarkers.push({
          type,
          start,
          end: start + match[0].length,
        })
      }
    }

    collectIntentMarkers(
      /\b(?:nascond(?:i(?:lo|la|li|le)?|ere|er(?:lo|la|li|le))|disattiv(?:a(?:lo|la|li|le)?|are|ar(?:lo|la|li|le))|elimin(?:a(?:lo|la|li|le)?|are|ar(?:lo|la|li|le))|rimuov(?:i(?:lo|la|li|le)?|ere|er(?:lo|la|li|le))|cancell(?:a(?:lo|la|li|le)?|are|ar(?:lo|la|li|le))|togl(?:i(?:lo|la|li|le)?|iere|ier(?:lo|la|li|le)))\b/g,
      'hide',
    )
    collectIntentMarkers(
      /\b(?:mostra(?:re)?\s+di\s+nuovo|rendi\s+nuovamente\s+visibile|rendere\s+nuovamente\s+visibile|riattiv(?:a(?:lo|la|li|le)?|are|ar(?:lo|la|li|le))|attiv(?:a(?:lo|la|li|le)?|are|ar(?:lo|la|li|le))|riabilit(?:a(?:lo|la|li|le)?|are|ar(?:lo|la|li|le))|ripristin(?:a(?:lo|la|li|le)?|are|ar(?:lo|la|li|le))|riaccend(?:i(?:lo|la|li|le)?|ere|er(?:lo|la|li|le))|rimett(?:i(?:lo|la|li|le)?|ere|er(?:lo|la|li|le)))\b/g,
      'reactivate',
    )
    intentMarkers.sort((left, right) => left.start - right.start)

    if (intentMarkers.length > 0) {
      const negationMarkers = Array.from(
        normalizedPrompt.matchAll(/\b(?:non|mai|evita|evitare|senza)\b/g),
        (match) => {
          const start = match.index ?? 0
          return { start, end: start + match[0].length }
        },
      )
      const allowedNegationLinkWords = new Set([
        'assolutamente',
        'devi',
        'devo',
        'di',
        'dover',
        'dovere',
        'piu',
        'voglio',
        'voler',
        'vorrei',
      ])
      const hasDirectlyNegatedIntent = negationMarkers.some((negation) =>
        intentMarkers.some((intent) => {
          if (negation.end > intent.start) {
            return false
          }

          const wordsBetween = normalizedPrompt
            .slice(negation.end, intent.start)
            .trim()
            .split(/\s+/)
            .filter((word) => word.length > 0)

          return (
            wordsBetween.length <= 3 &&
            wordsBetween.every((word) => allowedNegationLinkWords.has(word))
          )
        })
      )
      const createNegatedVisibilityResponse = () =>
        new Response(
          JSON.stringify({
            reply:
              'Non applicherò modifiche perché la richiesta contiene una negazione. Riscrivila indicando soltanto gli elementi da modificare.',
            summary:
              'Nessuna modifica: richiesta di visibilità negata o ambigua.',
            actions: [],
          }),
          { status: 200, headers: corsHeaders },
        )

      if (hasDirectlyNegatedIntent) {
        return createNegatedVisibilityResponse()
      }

      const entitiesByNormalizedName = new Map<
        string,
        { categories: Category[]; items: Item[] }
      >()

      for (const category of categories) {
        const normalizedName = normalizeText(category.name)

        if (!normalizedName) {
          continue
        }

        const entities = entitiesByNormalizedName.get(normalizedName) ?? {
          categories: [],
          items: [],
        }
        entities.categories.push(category)
        entitiesByNormalizedName.set(normalizedName, entities)
      }

      for (const item of items) {
        const normalizedName = normalizeText(item.name)

        if (!normalizedName) {
          continue
        }

        const entities = entitiesByNormalizedName.get(normalizedName) ?? {
          categories: [],
          items: [],
        }
        entities.items.push(item)
        entitiesByNormalizedName.set(normalizedName, entities)
      }

      const rawNameOccurrences: NameOccurrence[] = []

      for (const [normalizedName, entities] of entitiesByNormalizedName) {
        for (
          const occurrence of findWholeNameOccurrences(
            normalizedPrompt,
            normalizedName,
          )
        ) {
          rawNameOccurrences.push({
            normalizedName,
            ...occurrence,
            categories: entities.categories,
            items: entities.items,
          })
        }
      }

      const nameOccurrences = rawNameOccurrences
        .filter((occurrence, occurrenceIndex) =>
          !rawNameOccurrences.some((other, otherIndex) => {
            if (occurrenceIndex === otherIndex) {
              return false
            }

            const occurrenceLength = occurrence.end - occurrence.start
            const otherLength = other.end - other.start

            return (
              otherLength > occurrenceLength &&
              other.start <= occurrence.start &&
              other.end >= occurrence.end
            )
          })
        )
        .sort(
          (left, right) =>
            left.start - right.start ||
            (right.end - right.start) - (left.end - left.start),
        )

      const hasNegatedTarget = nameOccurrences.some((occurrence) => {
        const associatedIntent = intentMarkers
          .filter((intent) => intent.end <= occurrence.start)
          .at(-1)

        return (
          associatedIntent !== undefined &&
          negationMarkers.some(
            (negation) =>
              negation.start >= associatedIntent.end &&
              negation.end <= occurrence.start,
          )
        )
      })

      if (hasNegatedTarget) {
        return createNegatedVisibilityResponse()
      }

      if (nameOccurrences.length > 0) {
        const qualifierMarkers: QualifierMarker[] = []

        const collectQualifierMarkers = (
          pattern: RegExp,
          type: TargetQualifier,
        ) => {
          for (const match of normalizedPrompt.matchAll(pattern)) {
            const start = match.index ?? 0
            qualifierMarkers.push({
              type,
              start,
              end: start + match[0].length,
            })
          }
        }

        collectQualifierMarkers(/\b(?:categoria|categorie)\b/g, 'category')
        collectQualifierMarkers(
          /\b(?:piatto|piatti|prodotto|prodotti|portata|portate)\b/g,
          'item',
        )
        qualifierMarkers.sort((left, right) => left.start - right.start)

        const qualifierForOccurrence = (
          occurrence: NameOccurrence,
        ): TargetQualifier | null => {
          const lastIntent = intentMarkers
            .filter((marker) => marker.end <= occurrence.start)
            .at(-1)
          const lastQualifier = qualifierMarkers
            .filter(
              (marker) =>
                marker.end <= occurrence.start &&
                (!lastIntent || marker.start >= lastIntent.end),
            )
            .at(-1)

          return lastQualifier?.type ?? null
        }

        const targetDrafts: TargetDraft[] = nameOccurrences.map(
          (occurrence) => {
            const hasCategories = occurrence.categories.length > 0
            const hasItems = occurrence.items.length > 0
            const qualifier = qualifierForOccurrence(occurrence)
            let targetType: TargetQualifier | null = null

            if (hasCategories && !hasItems) {
              targetType = 'category'
            } else if (hasItems && !hasCategories) {
              targetType = 'item'
            } else if (qualifier) {
              targetType = qualifier
            }

            return { occurrence, targetType }
          },
        )

        const categoryQualifierByItemOccurrence = new Map<
          NameOccurrence,
          NameOccurrence
        >()
        const qualifierOnlyOccurrences = new Set<NameOccurrence>()

        const isCategoryRelation = (value: string) =>
          /^(?:(?:di|del|dello|della|dei|degli|delle|in|nel|nello|nella|nei|negli|nelle|dentro\s+la|dentro\s+le)\s+)?(?:categoria|categorie)$/
            .test(value) ||
          /^(?:di|del|dello|della|dei|degli|delle|in|nel|nello|nella|nei|negli|nelle)$/
            .test(value)

        for (const draft of targetDrafts) {
          if (draft.targetType !== 'item') {
            continue
          }

          const nextIntent = intentMarkers.find(
            (marker) => marker.start > draft.occurrence.end,
          )
          const categoryQualifier = nameOccurrences.find((occurrence) => {
            if (
              occurrence.start <= draft.occurrence.end ||
              occurrence.categories.length === 0 ||
              (nextIntent && occurrence.start >= nextIntent.start)
            ) {
              return false
            }

            const between = normalizedPrompt
              .slice(draft.occurrence.end, occurrence.start)
              .trim()

            return isCategoryRelation(between)
          })

          if (categoryQualifier) {
            categoryQualifierByItemOccurrence.set(
              draft.occurrence,
              categoryQualifier,
            )
            qualifierOnlyOccurrences.add(categoryQualifier)
          }
        }

        const effectiveDrafts = targetDrafts.filter(
          (draft) => !qualifierOnlyOccurrences.has(draft.occurrence),
        )
        const ambiguityMessages: string[] = []
        const intentByOccurrence = new Map<
          NameOccurrence,
          VisibilityIntent
        >()
        let currentIntent: VisibilityIntent | null = null
        let previousTargetEnd = 0

        for (const draft of effectiveDrafts) {
          const newIntentMarkers = intentMarkers.filter(
            (marker) =>
              marker.start >= previousTargetEnd &&
              marker.end <= draft.occurrence.start,
          )
          const newIntentTypes = new Set(
            newIntentMarkers.map((marker) => marker.type),
          )

          if (newIntentTypes.size > 1) {
            ambiguityMessages.push(
              `Per '${draft.occurrence.normalizedName}' specifica una sola operazione: nascondere oppure riattivare.`,
            )
          } else if (newIntentMarkers.length > 0) {
            currentIntent = newIntentMarkers.at(-1)?.type ?? currentIntent
          }

          if (currentIntent) {
            intentByOccurrence.set(draft.occurrence, currentIntent)
          } else {
            ambiguityMessages.push(
              `Specifica se vuoi nascondere o riattivare '${draft.occurrence.normalizedName}'.`,
            )
          }

          previousTargetEnd = draft.occurrence.end
        }

        const resolvedTargets: ResolvedTarget[] = []

        for (const draft of effectiveDrafts) {
          const intent = intentByOccurrence.get(draft.occurrence)

          if (!intent) {
            continue
          }

          if (!draft.targetType) {
            const exactName =
              draft.occurrence.categories[0]?.name ??
              draft.occurrence.items[0]?.name ??
              draft.occurrence.normalizedName
            ambiguityMessages.push(
              `Il nome '${exactName}' identifica sia una categoria sia un piatto: specifica "categoria ${exactName}" oppure "piatto ${exactName}".`,
            )
            continue
          }

          if (draft.targetType === 'category') {
            if (draft.occurrence.categories.length !== 1) {
              const exactName =
                draft.occurrence.categories[0]?.name ??
                draft.occurrence.normalizedName
              ambiguityMessages.push(
                `La categoria '${exactName}' non è univoca: specifica quale categoria intendi.`,
              )
              continue
            }

            resolvedTargets.push({
              targetType: 'category',
              intent,
              start: draft.occurrence.start,
              category: draft.occurrence.categories[0],
            })
            continue
          }

          const categoryQualifier = categoryQualifierByItemOccurrence.get(
            draft.occurrence,
          )
          const qualifiedCategoryName = categoryQualifier?.normalizedName ?? ''
          const matchingItems = draft.occurrence.items.filter(
            (item) =>
              !qualifiedCategoryName ||
              normalizeText(item.categoryName) === qualifiedCategoryName,
          )
          const exactItemName =
            draft.occurrence.items[0]?.name ??
            draft.occurrence.normalizedName

          if (matchingItems.length !== 1) {
            if (qualifiedCategoryName) {
              const exactCategoryName =
                categoryQualifier?.categories[0]?.name ??
                qualifiedCategoryName
              ambiguityMessages.push(
                matchingItems.length === 0
                  ? `Il piatto '${exactItemName}' non risulta nella categoria '${exactCategoryName}': verifica nome e categoria.`
                  : `Il piatto '${exactItemName}' non è univoco nella categoria '${exactCategoryName}': specifica quale intendi.`,
              )
            } else {
              const categoryNames = Array.from(
                new Set(
                  draft.occurrence.items
                    .map((item) => item.categoryName)
                    .filter((name) => name.length > 0),
                ),
              )
              const categoryList =
                categoryNames.length > 0
                  ? ` (${categoryNames.join(', ')})`
                  : ''
              ambiguityMessages.push(
                `Il piatto '${exactItemName}' è presente in più categorie${categoryList}: specifica la categoria.`,
              )
            }
            continue
          }

          resolvedTargets.push({
            targetType: 'item',
            intent,
            start: draft.occurrence.start,
            item: matchingItems[0],
          })
        }

        const ignoredWords = new Set([
          'a',
          'adesso',
          'ai',
          'agli',
          'al',
          'alla',
          'alle',
          'allo',
          'anche',
          'cortesemente',
          'cortesia',
          'da',
          'dagli',
          'dai',
          'dal',
          'dalla',
          'dalle',
          'dallo',
          'devo',
          'dei',
          'del',
          'della',
          'delle',
          'dello',
          'degli',
          'di',
          'e',
          'ed',
          'favore',
          'fra',
          'gentilmente',
          'gli',
          'i',
          'il',
          'in',
          'la',
          'le',
          'lo',
          'menu',
          'nel',
          'nella',
          'nelle',
          'nello',
          'negli',
          'nei',
          'o',
          'od',
          'ora',
          'oppure',
          'per',
          'piacere',
          'poi',
          'potresti',
          'puoi',
          'su',
          'tra',
          'un',
          'una',
          'uno',
          'voglio',
          'vorrei',
        ])
        const uncoveredPrompt = normalizedPrompt.split('')
        const coveredRanges = [
          ...intentMarkers,
          ...qualifierMarkers,
          ...nameOccurrences,
        ]

        for (const range of coveredRanges) {
          for (let index = range.start; index < range.end; index += 1) {
            uncoveredPrompt[index] = ' '
          }
        }

        const unresolvedWords = uncoveredPrompt
          .join('')
          .split(/\s+/)
          .filter((word) => word.length > 0 && !ignoredWords.has(word))

        if (unresolvedWords.length > 0) {
          ambiguityMessages.push(
            `Non riconosco con certezza il target '${unresolvedWords.join(' ')}': usa il nome esatto presente nel menu e, se serve, specifica categoria o piatto.`,
          )
        }

        if (resolvedTargets.length === 0 && ambiguityMessages.length === 0) {
          ambiguityMessages.push(
            'Specifica almeno una categoria o un piatto del menu da modificare.',
          )
        }

        const targetIntentByKey = new Map<string, VisibilityIntent>()

        for (const target of resolvedTargets) {
          const key =
            target.targetType === 'category'
              ? `category|${normalizeText(target.category.name)}`
              : [
                  'item',
                  normalizeText(target.item.name),
                  normalizeText(target.item.categoryName),
                ].join('|')
          const previousIntent = targetIntentByKey.get(key)

          if (previousIntent && previousIntent !== target.intent) {
            const exactName =
              target.targetType === 'category'
                ? target.category.name
                : target.item.name
            ambiguityMessages.push(
              `Per '${exactName}' hai indicato operazioni in conflitto: scegli se nasconderlo oppure riattivarlo.`,
            )
          } else {
            targetIntentByKey.set(key, target.intent)
          }
        }

        for (const target of resolvedTargets) {
          if (
            target.targetType === 'item' &&
            target.intent === 'reactivate' &&
            !target.item.categoryActive
          ) {
            const matchingCategories = categories.filter(
              (category) =>
                normalizeText(category.name) ===
                normalizeText(target.item.categoryName),
            )

            if (matchingCategories.length !== 1) {
              ambiguityMessages.push(
                `Per riattivare il piatto '${target.item.name}', specifica in modo univoco la categoria da riattivare.`,
              )
            }
          }
        }

        if (ambiguityMessages.length > 0) {
          const uniqueMessages = Array.from(new Set(ambiguityMessages))

          return new Response(
            JSON.stringify({
              reply:
                `Non applicherò modifiche. ${uniqueMessages.join(' ')}`,
              summary:
                'Nessuna modifica: richiesta di visibilità da chiarire.',
              actions: [],
            }),
            { status: 200, headers: corsHeaders },
          )
        }

        const deterministicActions: Record<string, unknown>[] = []
        const deterministicActionKeys = new Set<string>()
        const statusMessages: string[] = []
        const statusKeys = new Set<string>()

        const pushDeterministicAction = (
          action: Record<string, unknown>,
        ) => {
          const key = [
            String(action.type ?? ''),
            normalizeText(String(action.name ?? '')),
            normalizeText(String(action.categoryName ?? '')),
          ].join('|')

          if (!deterministicActionKeys.has(key)) {
            deterministicActionKeys.add(key)
            deterministicActions.push(action)
          }
        }

        const pushStatusMessage = (key: string, message: string) => {
          if (!statusKeys.has(key)) {
            statusKeys.add(key)
            statusMessages.push(message)
          }
        }

        for (
          const target of resolvedTargets.sort(
            (left, right) => left.start - right.start,
          )
        ) {
          if (target.targetType === 'category') {
            if (target.intent === 'hide') {
              if (target.category.active) {
                pushDeterministicAction({
                  type: 'hide_category',
                  name: target.category.name,
                })
              } else {
                pushStatusMessage(
                  `hide_category|${normalizeText(target.category.name)}`,
                  `La categoria '${target.category.name}' è già nascosta.`,
                )
              }
            } else if (!target.category.active) {
              pushDeterministicAction({
                type: 'reactivate_category',
                name: target.category.name,
              })
            } else {
              pushStatusMessage(
                `reactivate_category|${normalizeText(target.category.name)}`,
                `La categoria '${target.category.name}' è già attiva e visibile.`,
              )
            }

            continue
          }

          if (target.intent === 'hide') {
            if (target.item.active) {
              pushDeterministicAction({
                type: 'hide_item',
                name: target.item.name,
                ...(target.item.categoryName
                  ? { categoryName: target.item.categoryName }
                  : {}),
              })
            } else {
              pushStatusMessage(
                [
                  'hide_item',
                  normalizeText(target.item.name),
                  normalizeText(target.item.categoryName),
                ].join('|'),
                `Il piatto '${target.item.name}' è già nascosto dal menu.`,
              )
            }

            continue
          }

          if (!target.item.categoryActive) {
            pushStatusMessage(
              [
                'reactivate_item_blocked',
                normalizeText(target.item.name),
                normalizeText(target.item.categoryName),
              ].join('|'),
              `Prima di riattivare il piatto "${target.item.name}", devi riattivare la categoria "${target.item.categoryName}".`,
            )
          } else if (!target.item.active) {
            pushDeterministicAction({
              type: 'reactivate_item',
              name: target.item.name,
              ...(target.item.categoryName
                ? { categoryName: target.item.categoryName }
                : {}),
            })
          } else {
            pushStatusMessage(
              [
                'reactivate_item',
                normalizeText(target.item.name),
                normalizeText(target.item.categoryName),
              ].join('|'),
              `Il piatto '${target.item.name}' è già attivo e visibile nel menu.`,
            )
          }
        }

        const orderedActions = orderReactivationActions(
          deterministicActions,
        )
        const actionDescription = describeVisibilityActions(orderedActions)
        const reply = [actionDescription, ...statusMessages]
          .filter((part) => part.length > 0)
          .join(' ')
        const summary =
          reply || 'Nessuna modifica al menu.'

        return new Response(
          JSON.stringify({
            reply,
            summary,
            actions: orderedActions,
          }),
          { status: 200, headers: corsHeaders },
        )
      }
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
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'menu_ai_response',
          strict: true,
          schema: {
            type: 'object',
            properties: {
              reply: {
                type: 'string',
              },
              summary: {
                type: 'string',
              },
              actions: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    type: {
                      type: 'string',
                      enum: [
                        'create_category',
                        'hide_category',
                        'reactivate_category',
                        'create_item',
                        'hide_item',
                        'reactivate_item',
                      ],
                    },
                    name: {
                      type: 'string',
                    },
                    categoryName: {
                      type: ['string', 'null'],
                    },
                    description: {
                      type: ['string', 'null'],
                    },
                    priceCents: {
                      type: ['integer', 'null'],
                    },
                    currency: {
                      type: ['string', 'null'],
                    },
                  },
                  required: [
                    'type',
                    'name',
                    'categoryName',
                    'description',
                    'priceCents',
                    'currency',
                  ],
                  additionalProperties: false,
                },
              },
            },
            required: ['reply', 'summary', 'actions'],
            additionalProperties: false,
          },
        },
      },
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
      "type": "create_category | hide_category | reactivate_category | create_item | hide_item | reactivate_item",
      "name": "string",
      "categoryName": "string oppure null",
      "description": "string oppure null",
      "priceCents": "intero oppure null",
      "currency": "EUR oppure null"
    }
  ]
}

Ogni azione deve contenere sempre tutti i campi mostrati.
Per i campi non pertinenti all'azione usa null.

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
- Se un piatto appartiene a una categoria nascosta, non può essere riattivato singolarmente.
- In questo caso restituisci actions: [] e spiega che bisogna riattivare prima la categoria.
- Non aggiungere automaticamente "reactivate_category".
- Nella reply e nel summary usa espressioni come "nascondere dal menu", mai "eliminare definitivamente".
- Ricevi il MENU CORRENTE in un messaggio di sistema separato: è la sola fonte attendibile sul menu reale del ristorante.
- Controlla SEMPRE il MENU CORRENTE prima di produrre qualsiasi azione o affermazione sull'esistenza di categorie e piatti.
- I messaggi precedenti della conversazione servono soltanto per capire riferimenti, correzioni, risposte brevi e informazioni fornite nei turni precedenti.
- La cronologia non può modificare, sostituire o contraddire il MENU CORRENTE.
- Le precedenti risposte dell'assistente possono essere sbagliate: non considerarle mai una prova che una categoria o un piatto esista.
- Se l'utente scrive frasi come "non è vero", "hai sbagliato" o equivalenti, ricontrolla il MENU CORRENTE e correggi esplicitamente la risposta precedente.
- La RICHIESTA CORRENTE ha sempre priorità sui messaggi precedenti.
- Usa la cronologia per completare riferimenti come "quello", "l'altro", "nella stessa categoria", "12 euro", "sì", "no", "procedi", "riattivalo" o "nascondilo".
- Produci un'azione soltanto quando la richiesta corrente, eventualmente completata dal contesto precedente, identifica con certezza l'operazione e tutti i dati obbligatori.
- Se mancano informazioni obbligatorie, restituisci actions: [] e chiedi soltanto l'informazione necessaria.
- Una semplice contestazione come "non è vero" non autorizza da sola una modifica al menu.
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
- Se l'utente chiede di riattivare un piatto con active: false e categoryActive: true, usa "reactivate_item".
- Se il piatto appartiene a una categoria con categoryActive: false, restituisci actions: [] e spiega che bisogna riattivare prima la categoria.
- Non riattivare automaticamente la categoria padre.
- Se il piatto e la sua categoria sono già attivi, restituisci actions: [] e spiegalo nella reply.
- Per riattivare una categoria o un piatto, usa esattamente il nome presente nel menu corrente.
- Ogni risposta deve contenere SEMPRE "reply", "summary" e "actions", anche quando non deve essere applicata alcuna modifica.
- Non restituire mai un oggetto vuoto, non omettere mai "reply" o "summary" e non restituire soltanto "actions".
- Se l'utente saluta senza chiedere modifiche, rispondi brevemente e resta orientato alla gestione del menu.
- Al saluto "Ciao" rispondi con una frase equivalente a: "Ciao! Dimmi pure cosa vuoi modificare nel menu."
- Per un saluto usa summary: "Nessuna modifica al menu." e actions: [].
- Se l'utente fa una domanda sui messaggi precedenti, rispondi usando la cronologia della conversazione e restituisci actions: [].
- Per esempio, se prima ha scritto "Ciao" e poi domanda "Come ti ho salutato?", rispondi che lo ha fatto dicendo "Ciao".
- Una domanda sulla conversazione non deve produrre modifiche al menu, salvo che contenga anche una richiesta esplicita e completa di modifica.
- Se l'utente fa una domanda non collegata alla gestione del menu o alla conversazione corrente, rispondi brevemente e riportalo alla gestione del menu senza inventare azioni.
- Se il nome della categoria o del piatto non è chiaro, non inventare: restituisci actions: [].
- "priceCents" deve essere un intero in centesimi.
- "currency" deve essere "EUR" se non specificato.
- reply e summary devono descrivere cosa verrà fatto, non fingere che il database sia già stato aggiornato.
- Non inventare campi extra.
          `.trim(),
        },
        {
          role: 'system',
          content:
            'MENU CORRENTE — FONTE ATTENDIBILE:\n' +
            serializedMenuContext,
        },
        ...effectiveConversationContext,
        {
          role: 'user',
          content:
            `RICHIESTA CORRENTE:\n${prompt}`,
        },
      ],
      temperature: 0,
      max_completion_tokens: 300,
    })

    const content = completion.choices[0]?.message?.content ?? '{}'
    const parsed = JSON.parse(content)

    let reply =
      typeof parsed.reply === 'string' && parsed.reply.trim().length > 0
        ? parsed.reply.trim()
        : 'Non sono riuscito a formulare una risposta. Riprova.'

    let summary =
      typeof parsed.summary === 'string' && parsed.summary.trim().length > 0
        ? parsed.summary.trim()
        : 'Nessuna modifica al menu.'

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
    const verificationMessages: string[] = []

    const pushVerificationMessage = (message: string) => {
      if (!verificationMessages.includes(message)) {
        verificationMessages.push(message)
      }
    }

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

    for (const action of rawActions) {
      const type =
        typeof action.type === 'string' ? action.type : ''

      if (!allowedActionTypes.has(type)) {
        continue
      }

      const actionName =
        typeof action.name === 'string' ? action.name.trim() : ''
      const actionCategoryName =
        typeof action.categoryName === 'string'
          ? action.categoryName.trim()
          : ''

      if (type === 'create_category') {
        if (!actionName) {
          pushVerificationMessage(
            'Non posso creare la categoria perché manca un nome valido.',
          )
          continue
        }

        const matchingCategories = categories.filter(
          (category) =>
            normalizeText(category.name) === normalizeText(actionName),
        )

        if (matchingCategories.length > 0) {
          pushVerificationMessage(
            `La categoria '${matchingCategories[0].name}' esiste già nel menu.`,
          )
          continue
        }

        pushUniqueAction({
          type: 'create_category',
          name: actionName,
        })
        continue
      }

      if (type === 'create_item') {
        if (!actionName || !actionCategoryName) {
          pushVerificationMessage(
            'Non posso aggiungere il piatto perché mancano nome o categoria.',
          )
          continue
        }

        const matchingCategories = categories.filter(
          (category) =>
            normalizeText(category.name) ===
            normalizeText(actionCategoryName),
        )

        if (matchingCategories.length === 0) {
          pushVerificationMessage(
            `La categoria '${actionCategoryName}' non esiste nel menu attuale.`,
          )
          continue
        }

        if (matchingCategories.length > 1) {
          pushVerificationMessage(
            `La categoria '${actionCategoryName}' non è univoca nel menu attuale.`,
          )
          continue
        }

        const matchingCategory = matchingCategories[0]

        if (!matchingCategory.active) {
          pushVerificationMessage(
            `La categoria '${matchingCategory.name}' è nascosta. Riattivala prima di aggiungere il piatto.`,
          )
          continue
        }

        const duplicateItems = items.filter(
          (item) =>
            normalizeText(item.name) === normalizeText(actionName) &&
            normalizeText(item.categoryName) ===
              normalizeText(matchingCategory.name),
        )

        if (duplicateItems.length > 0) {
          pushVerificationMessage(
            `Il piatto '${duplicateItems[0].name}' esiste già nella categoria '${matchingCategory.name}'.`,
          )
          continue
        }

        const priceCents =
          typeof action.priceCents === 'number' &&
          Number.isInteger(action.priceCents) &&
          action.priceCents > 0
            ? action.priceCents
            : null

        if (priceCents === null) {
          pushVerificationMessage(
            `Per aggiungere il piatto '${actionName}' nella categoria '${matchingCategory.name}' manca un prezzo valido.`,
          )
          continue
        }

        const description =
          typeof action.description === 'string' &&
          action.description.trim().length > 0
            ? action.description.trim()
            : null

        pushUniqueAction({
          type: 'create_item',
          name: actionName,
          categoryName: matchingCategory.name,
          description,
          priceCents,
          currency: 'EUR',
        })
        continue
      }

      if (
        type === 'hide_category' ||
        type === 'reactivate_category'
      ) {
        const matchingCategories = resolveCategoriesForAction(action)

        if (matchingCategories.length === 0) {
          pushVerificationMessage(
            `La categoria '${actionName}' non esiste nel menu attuale.`,
          )
          continue
        }

        if (matchingCategories.length > 1) {
          pushVerificationMessage(
            `La categoria '${actionName}' non è univoca nel menu attuale.`,
          )
          continue
        }

        const matchingCategory = matchingCategories[0]

        if (type === 'hide_category') {
          if (matchingCategory.active) {
            pushUniqueAction({
              type: 'hide_category',
              name: matchingCategory.name,
            })
          } else {
            pushVerificationMessage(
              `La categoria '${matchingCategory.name}' è già nascosta.`,
            )
          }

          continue
        }

        if (!matchingCategory.active) {
          pushUniqueAction({
            type: 'reactivate_category',
            name: matchingCategory.name,
          })
        } else {
          pushVerificationMessage(
            `La categoria '${matchingCategory.name}' è già attiva e visibile.`,
          )
        }

        continue
      }

      if (type === 'hide_item' || type === 'reactivate_item') {
        const matchingItems = resolveItemsForAction(action)

        if (matchingItems.length === 0) {
          const categoryPart = actionCategoryName
            ? ` nella categoria '${actionCategoryName}'`
            : ''

          pushVerificationMessage(
            `Il piatto '${actionName}' non esiste${categoryPart} nel menu attuale.`,
          )
          continue
        }

        if (matchingItems.length > 1) {
          pushVerificationMessage(
            `Il piatto '${actionName}' non è univoco: specifica la categoria.`,
          )
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
          } else {
            pushVerificationMessage(
              `Il piatto '${matchingItem.name}' è già nascosto dal menu.`,
            )
          }

          continue
        }

        if (!matchingItem.categoryActive) {
          pushVerificationMessage(
            `Prima di riattivare il piatto "${matchingItem.name}", devi riattivare la categoria "${matchingItem.categoryName}".`,
          )
          continue
        }

        if (!matchingItem.active) {
          pushUniqueAction({
            type: 'reactivate_item',
            name: matchingItem.name,
            ...(matchingItem.categoryName
              ? { categoryName: matchingItem.categoryName }
              : {}),
          })
        } else {
          pushVerificationMessage(
            `Il piatto '${matchingItem.name}' è già attivo e visibile nel menu.`,
          )
        }

        continue
      }
    }

    actions = orderReactivationActions(actions)

    const verifiedActionDescription =
      describeVerifiedMenuActions(actions)

    const mustUseVerifiedMenuReply =
      menuMutationRequest ||
      actions.length > 0 ||
      verificationMessages.length > 0

    if (mustUseVerifiedMenuReply) {
      const verifiedReplyParts = [
        verifiedActionDescription,
        ...verificationMessages,
      ].filter((part) => part.length > 0)

      if (verifiedReplyParts.length > 0) {
        reply = verifiedReplyParts.join(' ')
        summary = reply
      } else {
        reply =
          'Non applicherò modifiche: la richiesta non ha prodotto operazioni verificabili rispetto al menu attuale. Riformula usando i nomi esatti presenti nel menu.'
        summary = 'Nessuna modifica al menu.'
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
