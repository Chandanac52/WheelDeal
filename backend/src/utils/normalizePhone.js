/**
 * Normalizes any phone number string to a bare E.164-style form: a leading
 * "+" followed by digits only, no spaces/dashes/parens.
 *
 * This exists because Firebase always reports phone_number in strict E.164
 * ("+919123456780" — no spaces), but phone numbers were being *stored*
 * elsewhere (seed data, anything a user might type) as "+91 91234 56780"
 * with spaces for readability. Looking up `where: { phone }` with the raw
 * Firebase value against a spaced value stored in the DB never matches —
 * Postgres does an exact string comparison, not "same number, different
 * formatting". That mismatch is what caused a real seeded account (e.g.
 * Priya Menon) to silently get a brand-new duplicate "WheelDeal User"
 * account created on login instead of ever finding the existing one: the
 * find-by-phone lookup just came up empty.
 *
 * Every place a phone number is looked up, created, or updated needs to
 * run it through this first — that's what guarantees two different
 * spellings of the same number can never diverge into two different rows.
 */
function normalizePhone(phone) {
  if (!phone) return null;
  const digits = String(phone).replace(/[^\d]/g, '');
  if (!digits) return null;
  return `+${digits}`;
}

module.exports = { normalizePhone };