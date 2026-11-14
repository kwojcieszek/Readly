// Readly reader runtime: styling, tap-to-translate and progress reporting.
// Injected into every chapter; talks to the app through the `readly` handler.
(function () {
  'use strict';
  if (window.Readly) { return; }

  var config = window.__readlyConfig || {};
  var HIGHLIGHT = 'readly';

  function post(message) {
    try { window.webkit.messageHandlers.readly.postMessage(message); } catch (error) { /* not in app */ }
  }

  // ---- Styling and page layout ---------------------------------------------
  //
  // A chapter is laid out in CSS columns, each exactly one viewport wide, so
  // page N starts at horizontal scroll offset N * viewport width.

  var styleElement = null;
  var currentStyle = config.style || null;
  var page = 0;
  var pageCount = 1;
  var pageWidth = 1;
  var isReady = false;

  function buildCSS(style) {
    var width = window.innerWidth;
    var height = window.innerHeight;
    var maxTextWidth = 46 * 16;
    var paddingX = Math.max(14, Math.round((width - maxTextWidth) / 2));
    var paddingY = 28;
    var rules = [
      'html { background: ' + style.background + ' !important;' +
        ' height: ' + height + 'px !important; overflow: hidden !important; margin: 0 !important; padding: 0 !important;' +
        ' -webkit-text-size-adjust: 100% !important; touch-action: manipulation; }',
      'body { background: transparent !important; color: ' + style.text + ' !important;' +
        ' box-sizing: border-box !important; width: auto !important; max-width: none !important;' +
        ' height: ' + height + 'px !important; margin: 0 !important;' +
        ' padding: ' + paddingY + 'px ' + paddingX + 'px !important;' +
        ' column-width: ' + (width - 2 * paddingX) + 'px !important; column-gap: ' + (2 * paddingX) + 'px !important;' +
        ' column-fill: auto !important; overflow: visible !important;' +
        ' line-height: 1.65 !important; overflow-wrap: break-word; -webkit-tap-highlight-color: transparent; }',
      'body * { color: inherit !important; background-color: transparent !important; }',
      'a, a * { color: ' + style.link + ' !important; }',
      'img, svg, video { max-width: 100% !important; max-height: ' + (height - 2 * paddingY) + 'px !important;' +
        ' height: auto !important; object-fit: contain; break-inside: avoid; }',
      'pre { white-space: pre-wrap !important; }',
      '::highlight(' + HIGHLIGHT + ') { background-color: ' + style.highlight + '; }'
    ];
    if (style.fontFamily) {
      rules.push('body, body *:not(pre):not(code):not(kbd):not(samp) { font-family: ' +
        style.fontFamily + ' !important; }');
    }
    return rules.join('\n');
  }

  function ensureViewport() {
    if (!document.head || document.querySelector('meta[name="viewport"]')) { return; }
    var meta = document.createElement('meta');
    meta.setAttribute('name', 'viewport');
    meta.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no');
    document.head.appendChild(meta);
  }

  // The range that is highlighted or selected, so the app can anchor its
  // action bar to it.
  var markedRange = null;

  // Bounding box of the marked text in viewport coordinates, or null when it is
  // not on the visible page. `shiftX` moves the box, for a slide that has just begun.
  function markedRect(shiftX) {
    if (!markedRange) { return null; }
    var box = markedRange.getBoundingClientRect();
    if (!box || (box.width === 0 && box.height === 0)) { return null; }
    var left = box.left + (shiftX || 0);
    if (left + box.width <= 0 || left >= window.innerWidth) { return null; }
    return { x: left, y: box.top, width: box.width, height: box.height };
  }

  function report(shiftX) {
    if (!isReady) { return; }
    post({
      type: 'layout',
      page: page,
      pageCount: pageCount,
      width: window.innerWidth,
      height: window.innerHeight,
      token: config.token || 0,
      selection: markedRect(shiftX)
    });
  }

  function clampPage(target) {
    return Math.min(pageCount - 1, Math.max(0, Math.round(target)));
  }

  // Page turns slide the whole chapter with a GPU-composited transform, then
  // swap the transform for the equivalent scroll offset once the slide ends.
  var SLIDE_MS = 320;
  var slideTimer = null;

  function finishSlide() {
    if (!slideTimer) { return; }
    clearTimeout(slideTimer);
    slideTimer = null;
    document.body.style.transition = '';
    document.body.style.transform = '';
    window.scrollTo({ left: page * pageWidth, top: 0, behavior: 'instant' });
    // Commit the reset now, so the next slide starts from rest and not from
    // the transform this one ended on.
    void document.body.offsetWidth;
  }

  function slideToPage(target) {
    finishSlide();
    var from = page;
    page = clampPage(target);
    if (page === from) { return; }
    document.body.style.transition = 'transform ' + SLIDE_MS + 'ms cubic-bezier(0.22, 0.61, 0.36, 1)';
    document.body.style.transform = 'translate3d(' + ((from - page) * pageWidth) + 'px, 0, 0)';
    slideTimer = setTimeout(finishSlide, SLIDE_MS + 30);
    // The slide has not moved anything yet, so place the marked text where it will end up.
    report((from - page) * pageWidth);
  }

  function goToPage(target, animated) {
    if (animated) {
      slideToPage(target);
      return;
    }
    finishSlide();
    page = clampPage(target);
    window.scrollTo({ left: page * pageWidth, top: 0, behavior: 'instant' });
    report();
  }

  // Rebuilds the columns; `fraction` (0...1) says where in the chapter to land.
  function layout(fraction) {
    if (!currentStyle) { return; }
    finishSlide();
    if (fraction === undefined) { fraction = page / pageCount; }
    if (!styleElement) {
      styleElement = document.createElement('style');
      styleElement.id = 'readly-style';
      (document.head || document.documentElement).appendChild(styleElement);
    }
    styleElement.textContent = buildCSS(currentStyle);
    pageWidth = Math.max(1, window.innerWidth);
    pageCount = Math.max(1, Math.ceil((document.documentElement.scrollWidth - 2) / pageWidth));
    goToPage(Math.floor(fraction * pageCount + 0.0001), false);
  }

  function applyStyle(style) {
    if (!style) { return; }
    currentStyle = style;
    layout();
  }

  // A single key press can reach us twice: from the page's own key handler
  // and from the app's toolbar shortcut. Collapse such echoes into one turn.
  var lastTurnTime = 0;

  function turnPage(direction) {
    var now = Date.now();
    if (now - lastTurnTime < 60) { return; }
    lastTurnTime = now;
    var target = page + direction;
    if (target < 0 || target >= pageCount) {
      post({ type: 'boundary', forward: direction > 0 });
    } else {
      goToPage(target, true);
    }
  }

  function goToFragment(fragment) {
    var target = document.getElementById(fragment) || document.getElementsByName(fragment)[0];
    if (!target) { return; }
    var left = target.getBoundingClientRect().left + window.scrollX;
    goToPage(Math.floor((left + 1) / pageWidth), false);
  }

  function goToStart() {
    if (config.match) {
      goToMatch(config.match.query, config.match.index);
    } else if (config.fragment) {
      goToFragment(config.fragment);
    } else if (config.fromEnd) {
      goToPage(pageCount - 1, false);
    } else if (typeof config.page === 'number') {
      goToPage(config.page, false);
    }
  }

  // Keeps the view on a page boundary if something else scrolled it
  // (selection auto-scroll, find-in-page, an interrupted animation).
  var snapTimer = null;
  window.addEventListener('scroll', function () {
    clearTimeout(snapTimer);
    snapTimer = setTimeout(function () {
      if (slideTimer) { return; }
      var nearest = Math.min(pageCount - 1, Math.max(0, Math.round(window.scrollX / pageWidth)));
      if (nearest !== page || window.scrollY !== 0 || Math.abs(window.scrollX - nearest * pageWidth) > 1) {
        goToPage(nearest, false);
      }
    }, 180);
  }, { passive: true });

  var resizeTimer = null;
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () { layout(); }, 120);
  });

  // Wheel and trackpad: one page per gesture.
  //
  // A trackpad swipe is a stream of events whose size rises while the fingers
  // move, peaks, then decays through up to a second of "momentum". The page
  // turns at the start of that stream; everything after it belongs to the same
  // gesture until one of these shows a new one has begun:
  //   - a real pause in the stream,
  //   - a change of direction,
  //   - the stream decaying and then clearly growing again.
  // Times come from the events themselves, so a busy page that delivers
  // events late cannot fake a pause.
  var WHEEL_TRAVEL = 4;
  var WHEEL_PAUSE_MS = 180;
  var wheel = { lastTime: -1e9, travel: 0, turned: false, sign: 0, peak: 0, low: 0, decayed: false };

  function startsNewWheelGesture(size, sign) {
    if (sign !== wheel.sign) { return size >= 4; }
    if (!wheel.decayed) {
      if (size > wheel.peak) { wheel.peak = size; }
      if (size < wheel.peak * 0.4) {
        wheel.decayed = true;
        wheel.low = size;
      }
      return false;
    }
    if (size < wheel.low) {
      wheel.low = size;
      return false;
    }
    return size > wheel.low * 2.5 + 8;
  }

  window.addEventListener('wheel', function (event) {
    event.preventDefault();
    var now = event.timeStamp || performance.now();
    var paused = now - wheel.lastTime > WHEEL_PAUSE_MS;
    wheel.lastTime = now;

    var delta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
    if (delta === 0) { return; }
    var size = Math.abs(delta);
    var sign = delta > 0 ? 1 : -1;

    if (paused) {
      wheel.turned = false;
      wheel.travel = 0;
    }
    if (wheel.turned) {
      if (!startsNewWheelGesture(size, sign)) { return; }
      wheel.turned = false;
      wheel.travel = 0;
    }

    wheel.travel += delta;
    if (Math.abs(wheel.travel) >= WHEEL_TRAVEL) {
      wheel.turned = true;
      wheel.sign = wheel.travel > 0 ? 1 : -1;
      wheel.peak = size;
      wheel.low = 0;
      wheel.decayed = false;
      wheel.travel = 0;
      turnPage(wheel.sign);
    }
  }, { passive: false });

  document.addEventListener('keydown', function (event) {
    if (event.metaKey || event.ctrlKey || event.altKey) { return; }
    var direction = 0;
    if (event.key === 'ArrowRight' || event.key === 'PageDown' || (event.key === ' ' && !event.shiftKey)) {
      direction = 1;
    } else if (event.key === 'ArrowLeft' || event.key === 'PageUp' || (event.key === ' ' && event.shiftKey)) {
      direction = -1;
    }
    if (direction !== 0) {
      event.preventDefault();
      turnPage(direction);
    }
  });

  // ---- Text lookup -------------------------------------------------------------

  function segmenter(granularity) {
    var language = document.documentElement.lang || undefined;
    try {
      return new Intl.Segmenter(language, { granularity: granularity });
    } catch (error) {
      return new Intl.Segmenter(undefined, { granularity: granularity });
    }
  }

  function caretAt(x, y) {
    if (document.caretPositionFromPoint) {
      var position = document.caretPositionFromPoint(x, y);
      if (position) { return { node: position.offsetNode, offset: position.offset }; }
    }
    if (document.caretRangeFromPoint) {
      var range = document.caretRangeFromPoint(x, y);
      if (range) { return { node: range.startContainer, offset: range.startOffset }; }
    }
    return null;
  }

  // The nearest ancestor that lays out as a block: the unit a sentence lives in.
  function blockOf(node) {
    var element = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
    while (element && element !== document.body) {
      var display = getComputedStyle(element).display;
      if (display.indexOf('inline') !== 0 && display !== 'contents') { return element; }
      element = element.parentElement;
    }
    return document.body;
  }

  // Flattens a block's text nodes into one string, remembering where each starts.
  function textMap(block) {
    var walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT);
    var parts = [];
    var text = '';
    var node;
    while ((node = walker.nextNode())) {
      parts.push({ node: node, start: text.length });
      text += node.nodeValue;
    }
    return { parts: parts, text: text };
  }

  function domPoint(map, offset, isEnd) {
    for (var i = map.parts.length - 1; i >= 0; i--) {
      var part = map.parts[i];
      if (part.start < offset || (!isEnd && part.start === offset) || i === 0) {
        return { node: part.node, offset: Math.min(offset - part.start, part.node.nodeValue.length) };
      }
    }
    return null;
  }

  function rangeFor(map, start, end) {
    var from = domPoint(map, start, false);
    var to = domPoint(map, end, true);
    if (!from || !to) { return null; }
    var range = document.createRange();
    range.setStart(from.node, from.offset);
    range.setEnd(to.node, to.offset);
    return range;
  }

  function trimmedSpan(text, start, end) {
    while (start < end && /\s/.test(text[start])) { start++; }
    while (end > start && /\s/.test(text[end - 1])) { end--; }
    return { start: start, end: end };
  }

  function containsPoint(range, x, y) {
    var rects = range.getClientRects();
    for (var i = 0; i < rects.length; i++) {
      var rect = rects[i];
      if (x >= rect.left - 4 && x <= rect.right + 4 && y >= rect.top - 4 && y <= rect.bottom + 4) {
        return true;
      }
    }
    return false;
  }

  function wordAt(text, offset) {
    var segments = segmenter('word').segment(text);
    var candidates = [offset, offset - 1];
    for (var i = 0; i < candidates.length; i++) {
      var index = candidates[i];
      if (index < 0 || index >= text.length) { continue; }
      var segment = segments.containing(index);
      if (segment && segment.isWordLike) {
        return { start: segment.index, end: segment.index + segment.segment.length };
      }
    }
    return null;
  }

  function sentenceAt(text, offset) {
    var index = Math.min(Math.max(0, offset), text.length - 1);
    var segment = segmenter('sentence').segment(text).containing(index);
    if (!segment) { return null; }
    return trimmedSpan(text, segment.index, segment.index + segment.segment.length);
  }

  // Finds the word under a point, plus the sentence around it.
  function lookup(x, y) {
    var caret = caretAt(x, y);
    if (!caret || caret.node.nodeType !== Node.TEXT_NODE) { return null; }
    var map = textMap(blockOf(caret.node));
    var part = null;
    for (var i = 0; i < map.parts.length; i++) {
      if (map.parts[i].node === caret.node) { part = map.parts[i]; break; }
    }
    if (!part) { return null; }

    var word = wordAt(map.text, part.start + caret.offset);
    if (!word) { return null; }
    var wordRange = rangeFor(map, word.start, word.end);
    if (!wordRange || !containsPoint(wordRange, x, y)) { return null; }

    var sentence = sentenceAt(map.text, word.start) || word;
    return {
      word: map.text.slice(word.start, word.end),
      wordRange: wordRange,
      sentence: map.text.slice(sentence.start, sentence.end).replace(/\s+/g, ' '),
      sentenceRange: rangeFor(map, sentence.start, sentence.end)
    };
  }

  // ---- Highlight -----------------------------------------------------------------

  function highlight(range) {
    markedRange = range || null;
    if (!range || !window.CSS || !CSS.highlights || typeof Highlight === 'undefined') { return; }
    CSS.highlights.set(HIGHLIGHT, new Highlight(range));
  }

  function clearHighlight() {
    markedRange = null;
    if (window.CSS && CSS.highlights) { CSS.highlights.delete(HIGHLIGHT); }
  }

  // ---- Search ----------------------------------------------------------------------

  // The text nodes a reader can see, flattened like `textMap`.
  function bodyMap() {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        var tag = node.parentNode && node.parentNode.nodeName.toLowerCase();
        return tag === 'script' || tag === 'style' ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
      }
    });
    var parts = [];
    var text = '';
    var node;
    while ((node = walker.nextNode())) {
      parts.push({ node: node, start: text.length });
      text += node.nodeValue;
    }
    return { parts: parts, text: text };
  }

  // Shows and highlights the `index`-th (0-based) occurrence of `query` in the chapter;
  // falls back to the last occurrence when there are fewer.
  function goToMatch(query, index) {
    var words = String(query || '').trim().split(/\s+/).filter(Boolean).map(function (word) {
      return word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    });
    if (!words.length) { return false; }
    var pattern = new RegExp(words.join('\\s+'), 'gi');
    var map = bodyMap();
    var found = null;
    var match;
    var count = 0;
    while ((match = pattern.exec(map.text))) {
      found = match;
      if (count === index) { break; }
      count++;
      if (match[0].length === 0) { pattern.lastIndex++; }
    }
    if (!found) { return false; }
    var range = rangeFor(map, found.index, found.index + found[0].length);
    if (!range) { return false; }
    finishSlide();
    var left = range.getBoundingClientRect().left + window.scrollX;
    highlight(range);
    goToPage(Math.floor((left + 1) / pageWidth), false);
    return true;
  }

  // ---- Page text, for reading aloud ---------------------------------------------------

  // Left edge of the first rendered character at or after `index`.
  function characterLeft(node, index) {
    var range = document.createRange();
    for (var i = index; i < node.data.length; i++) {
      range.setStart(node, i);
      range.setEnd(node, i + 1);
      var rects = range.getClientRects();
      if (rects.length) { return rects[0].left; }
    }
    return Infinity;
  }

  // The first character of `node` laid out at or to the right of `x`. Columns
  // follow the text order, so the answer can be found by bisection.
  function firstOffsetFrom(node, x) {
    var low = 0;
    var high = node.data.length;
    while (low < high) {
      var middle = (low + high) >> 1;
      if (characterLeft(node, middle) >= x) { high = middle; } else { low = middle + 1; }
    }
    return low;
  }

  // The text of the visible page, one line per block.
  function pageText() {
    finishSlide();
    var width = window.innerWidth;
    var map = bodyMap();
    var range = document.createRange();
    var text = '';
    var lastBlock = null;
    for (var i = 0; i < map.parts.length; i++) {
      var node = map.parts[i].node;
      if (!node.data.trim()) { continue; }
      range.selectNodeContents(node);
      var rects = range.getClientRects();
      if (!rects.length) { continue; }
      var first = rects[0].left;
      var last = rects[rects.length - 1].left;
      if (last < 0) { continue; }
      if (first >= width) { break; }
      var start = first >= 0 ? 0 : firstOffsetFrom(node, 0);
      var end = last < width ? node.data.length : firstOffsetFrom(node, width);
      if (end <= start) { continue; }
      var block = blockOf(node);
      if (lastBlock && block !== lastBlock) { text += '\n'; }
      lastBlock = block;
      text += node.data.slice(start, end);
    }
    return text.replace(/[ \t\r\f\v]+/g, ' ').replace(/ ?\n ?/g, '\n').trim();
  }

  // ---- Taps: single = word, double = sentence -------------------------------------

  var DOUBLE_TAP_MS = 320;
  var pointerStart = null;
  var isPointerDown = false;
  var lastTap = null;
  var wordTimer = null;
  var selectionTimer = null;
  var lastSelection = '';
  var lastHit = null;
  var ignoreSelectionUntil = 0;

  function clearNativeSelection() {
    var selection = window.getSelection();
    if (selection) { selection.removeAllRanges(); }
    ignoreSelectionUntil = Date.now() + 900;
  }

  function translateAt(x, y, kind) {
    var hit = lookup(x, y);
    lastHit = hit;
    if (!hit) {
      clearHighlight();
      post({ type: 'dismiss' });
      return;
    }
    if (kind === 'sentence') {
      clearNativeSelection();
      highlight(hit.sentenceRange);
      post({ type: 'translate', kind: 'sentence', text: hit.sentence, selection: markedRect() });
    } else {
      highlight(hit.wordRange);
      post({ type: 'translate', kind: 'word', text: hit.word, context: hit.sentence, selection: markedRect() });
    }
  }

  function handleTap(x, y) {
    var now = Date.now();
    var isDouble = lastTap && now - lastTap.time < DOUBLE_TAP_MS &&
      Math.hypot(x - lastTap.x, y - lastTap.y) < 30;
    clearTimeout(wordTimer);
    wordTimer = null;

    if (isDouble) {
      lastTap = null;
      translateAt(x, y, 'sentence');
      return;
    }
    lastTap = { x: x, y: y, time: now };
    wordTimer = setTimeout(function () {
      wordTimer = null;
      var selection = window.getSelection();
      if (selection && !selection.isCollapsed) { return; }
      translateAt(x, y, 'word');
    }, DOUBLE_TAP_MS);
  }

  document.addEventListener('pointerdown', function (event) {
    if (!event.isPrimary || (event.pointerType === 'mouse' && event.button !== 0)) { return; }
    isPointerDown = true;
    pointerStart = { x: event.clientX, y: event.clientY, time: Date.now() };
  }, true);

  document.addEventListener('pointercancel', function () {
    isPointerDown = false;
    pointerStart = null;
  }, true);

  document.addEventListener('pointerup', function (event) {
    isPointerDown = false;
    var start = pointerStart;
    pointerStart = null;
    if (!start) { return; }
    var moved = Math.hypot(event.clientX - start.x, event.clientY - start.y);
    if (moved > 8 || Date.now() - start.time > 450) {
      scheduleSelectionCheck();
      return;
    }
    if (event.target && event.target.closest && event.target.closest('a[href]')) { return; }
    handleTap(event.clientX, event.clientY);
  }, true);

  // ---- Free selection ----------------------------------------------------------------

  function checkSelection() {
    if (isPointerDown || Date.now() < ignoreSelectionUntil) { return; }
    var selection = window.getSelection();
    if (!selection || selection.isCollapsed) {
      lastSelection = '';
      return;
    }
    var text = selection.toString().replace(/\s+/g, ' ').trim();
    if (!text || text === lastSelection) { return; }
    lastSelection = text;
    clearTimeout(wordTimer);
    clearHighlight();
    markedRange = selection.rangeCount ? selection.getRangeAt(0).cloneRange() : null;
    post({ type: 'translate', kind: 'selection', text: text, selection: markedRect() });
  }

  function scheduleSelectionCheck() {
    clearTimeout(selectionTimer);
    selectionTimer = setTimeout(checkSelection, 650);
  }

  document.addEventListener('selectionchange', scheduleSelectionCheck);

  // ---- Startup -------------------------------------------------------------------------

  // The first words of the visible page, used to label bookmarks.
  function pageSnippet() {
    finishSlide();
    if (!document.caretRangeFromPoint) { return ''; }
    var box = getComputedStyle(document.body);
    var range = document.caretRangeFromPoint(parseFloat(box.paddingLeft) + 4, parseFloat(box.paddingTop) + 6);
    if (!range) { return ''; }
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    var node = range.startContainer;
    var text = '';
    if (node.nodeType === Node.TEXT_NODE) {
      text = node.data.slice(range.startOffset);
      walker.currentNode = node;
    } else {
      walker.currentNode = node.childNodes[range.startOffset] || node;
      if (walker.currentNode.nodeType === Node.TEXT_NODE) { text = walker.currentNode.data; }
    }
    while (text.replace(/\s+/g, ' ').trim().length < 140 && (node = walker.nextNode())) {
      var tag = node.parentNode && node.parentNode.nodeName.toLowerCase();
      if (tag !== 'script' && tag !== 'style') { text += ' ' + node.data; }
    }
    return text.replace(/\s+/g, ' ').trim().slice(0, 140);
  }

  window.Readly = {
    pageSnippet: pageSnippet,
    pageText: pageText,
    goToMatch: goToMatch,
    // Widens the highlight from the tapped word to its sentence.
    markSentence: function () {
      if (!lastHit) { return; }
      highlight(lastHit.sentenceRange);
      report();
    },
    applyStyle: applyStyle,
    turnPage: turnPage,
    goToPage: function (target) { goToPage(target, false); },
    goToFragment: goToFragment,
    clearHighlight: clearHighlight
  };

  ensureViewport();
  layout(config.fraction || 0);
  goToStart();

  // Images and fonts can change the page count, so settle again once loaded.
  function finishLoading() {
    layout(config.fraction || 0);
    goToStart();
    isReady = true;
    report();
  }

  if (document.readyState === 'complete') {
    finishLoading();
  } else {
    window.addEventListener('load', finishLoading);
  }
})();
