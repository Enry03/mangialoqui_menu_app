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
    const names = group.map((action) => String(action.name ?? ''))
    const isCategory = String(group[0]?.type ?? '').endsWith('_category')
    const label = isCategory
      ? names.length === 1
        ? 'la categoria'
        : 'le categorie'
      : names.length === 1
        ? 'il piatto'
        : 'i piatti'

    return `${label} ${formatQuotedNames(names)}`
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

    const normalizedPrompt = normalizeText(prompt)
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
            const matchingCategory = categories.find(
              (category) =>
                normalizeText(category.name) ===
                normalizeText(target.item.categoryName),
            )

            if (matchingCategory) {
              pushDeterministicAction({
                type: 'reactivate_category',
                name: matchingCategory.name,
              })
            }
          }

          if (!target.item.active) {
            pushDeterministicAction({
              type: 'reactivate_item',
              name: target.item.name,
              ...(target.item.categoryName
                ? { categoryName: target.item.categoryName }
                : {}),
            })
          } else if (target.item.categoryActive) {
            pushStatusMessage(
              [
                'reactivate_item',
                normalizeText(target.item.name),
                normalizeText(target.item.categoryName),
              ].join('|'),
              `Il piatto '${target.item.name}' è già attivo e visibile nel menu.`,
            )
          } else {
            pushStatusMessage(
              [
                'reactivate_item_category',
                normalizeText(target.item.name),
                normalizeText(target.item.categoryName),
              ].join('|'),
              `Il piatto '${target.item.name}' è già attivo e tornerà visibile con la categoria '${target.item.categoryName}'.`,
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
          actionDescription ||
          'Nessuna modifica: gli elementi indicati sono già nello stato richiesto.'

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

    actions = orderReactivationActions(actions)
    const actionsAreOnlyVisibilityChanges =
      actions.length > 0 &&
      actions.every(
        (action) =>
          action.type === 'hide_category' ||
          action.type === 'reactivate_category' ||
          action.type === 'hide_item' ||
          action.type === 'reactivate_item',
      )

    if (actionsAreOnlyVisibilityChanges) {
      reply = describeVisibilityActions(actions)
      summary = reply
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