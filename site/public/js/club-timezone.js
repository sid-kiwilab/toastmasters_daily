/**
 * Club timezone helpers (no build step). Used on club pages and meeting creation.
 */
(function (global) {
  function zonedTimeToUtcDate(year, month, day, hour, minute, timeZone) {
    if (!timeZone) {
      return new Date(year, month - 1, day, hour, minute, 0, 0);
    }
    var formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timeZone,
      hour12: false,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    function partsFor(ms) {
      var parts = formatter.formatToParts(new Date(ms));
      var map = {};
      parts.forEach(function (p) {
        if (p.type !== 'literal') map[p.type] = p.value;
      });
      return map;
    }
    var ms = Date.UTC(year, month - 1, day, hour, minute, 0);
    for (var i = 0; i < 4; i++) {
      var p = partsFor(ms);
      var shown = Date.UTC(
        parseInt(p.year, 10),
        parseInt(p.month, 10) - 1,
        parseInt(p.day, 10),
        parseInt(p.hour, 10) % 24,
        parseInt(p.minute, 10),
        parseInt(p.second, 10) || 0
      );
      var desired = Date.UTC(year, month - 1, day, hour, minute, 0);
      ms += desired - shown;
    }
    return new Date(ms);
  }

  function getTimezoneAbbrev(date, timeZone) {
    if (!timeZone || !date) return '';
    try {
      var parts = new Intl.DateTimeFormat('en-US', {
        timeZone: timeZone,
        timeZoneName: 'short',
      }).formatToParts(date);
      var tzPart = parts.find(function (p) { return p.type === 'timeZoneName'; });
      return tzPart ? tzPart.value : '';
    } catch (e) {
      return '';
    }
  }

  function dateKeyFromYmd(year, month, day) {
    return year + '-' + String(month).padStart(2, '0') + '-' + String(day).padStart(2, '0');
  }

  function dateKeyFromInstant(date, timeZone) {
    var d = date instanceof Date ? date : new Date(date);
    if (!timeZone) {
      return dateKeyFromYmd(d.getFullYear(), d.getMonth() + 1, d.getDate());
    }
    var parts = new Intl.DateTimeFormat('en-US', {
      timeZone: timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(d);
    var map = {};
    parts.forEach(function (p) {
      if (p.type !== 'literal') map[p.type] = p.value;
    });
    return dateKeyFromYmd(parseInt(map.year, 10), parseInt(map.month, 10), parseInt(map.day, 10));
  }

  function todayDateKey(timeZone) {
    return dateKeyFromInstant(new Date(), timeZone || undefined);
  }

  function formatDateKeyLabel(dateKey, timeZone) {
    if (!dateKey) return '';
    var parts = dateKey.split('-').map(function (n) { return parseInt(n, 10); });
    if (parts.length !== 3 || parts.some(function (n) { return isNaN(n); })) return dateKey;
    if (timeZone) {
      var noon = zonedTimeToUtcDate(parts[0], parts[1], parts[2], 12, 0, timeZone);
      return noon.toLocaleDateString('en-US', {
        timeZone: timeZone,
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      });
    }
    var d = new Date(parts[0], parts[1] - 1, parts[2]);
    return d.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  }

  function formatMeetingInTimezone(date, timeZone) {
    if (!date) return { dateStr: '', timeStr: '', tzAbbr: '', dayName: '' };
    var d = date instanceof Date ? date : new Date(date);
    var opts = timeZone ? { timeZone: timeZone } : {};
    var dateStr = d.toLocaleDateString('en-US', Object.assign({}, opts, {
      month: 'short',
      day: '2-digit',
      year: 'numeric',
    }));
    var timeStr = d.toLocaleTimeString('en-US', Object.assign({}, opts, {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }));
    var dayName = d.toLocaleDateString('en-US', Object.assign({}, opts, {
      weekday: 'long',
    }));
    var tzAbbr = timeZone ? getTimezoneAbbrev(d, timeZone) : '';
    return { dateStr: dateStr, timeStr: timeStr, tzAbbr: tzAbbr, dayName: dayName };
  }

  global.ClubTimezone = {
    zonedTimeToUtcDate: zonedTimeToUtcDate,
    getTimezoneAbbrev: getTimezoneAbbrev,
    formatMeetingInTimezone: formatMeetingInTimezone,
    dateKeyFromYmd: dateKeyFromYmd,
    dateKeyFromInstant: dateKeyFromInstant,
    todayDateKey: todayDateKey,
    formatDateKeyLabel: formatDateKeyLabel,
  };
})(typeof window !== 'undefined' ? window : globalThis);
