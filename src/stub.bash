BATS_MOCK_TMPDIR="$(mktemp -u -d "${BATS_TMPDIR:-/tmp}/mock.XXXXXXXX")"
BATS_MOCK_BINDIR="${BATS_MOCK_TMPDIR}/bin"

export BATS_MOCK_REAL_mkdir=$(which mkdir)
export BATS_MOCK_REAL_ln=$(which ln)
export BATS_MOCK_REAL_touch=$(which touch)
export BATS_MOCK_REAL_rm=$(which rm)
export BATS_MOCK_REAL_find=$(which find)
export BATS_MOCK_REAL_basename=$(which basename)

PATH="$BATS_MOCK_BINDIR:$PATH"

stub() {
  local program="$1"
  local prefix="$(echo "$program" | tr a-z- A-Z_)"
  shift

  export "${prefix}_STUB_PLAN"="${BATS_MOCK_TMPDIR}/${program}-stub-plan"
  export "${prefix}_STUB_RUN"="${BATS_MOCK_TMPDIR}/${program}-stub-run"
  export "${prefix}_STUB_ERRORS"="${BATS_MOCK_TMPDIR}/${program}-stub-errors"
  export "${prefix}_STUB_END"=

  "$BATS_MOCK_REAL_mkdir" -p "${BATS_MOCK_BINDIR}"
  "$BATS_MOCK_REAL_ln" -sf "${BASH_SOURCE[0]%stub.bash}binstub" "${BATS_MOCK_BINDIR}/${program}"

  "$BATS_MOCK_REAL_touch" "${BATS_MOCK_TMPDIR}/${program}-stub-plan"
  for arg in "$@"; do printf "%s\n" "$arg" >> "${BATS_MOCK_TMPDIR}/${program}-stub-plan"; done
}

unstub() {
  local allow_missing=0
  if [ "$1" == "--allow-missing" ]; then
    allow_missing=1
    shift
  fi
  local program="$1"
  local prefix="$(echo "$program" | tr a-z- A-Z_)"
  local path="${BATS_MOCK_BINDIR}/${program}"

  export "${prefix}_STUB_END"=1

  local STATUS=0
  if [ -f "$path" ]; then
    "$path" || STATUS="$?"
  elif [ $allow_missing -eq 0 ]; then
    echo "$program is not stubbed" >&2
    STATUS=1
  fi

  "$BATS_MOCK_REAL_rm" -f "$path"
  "$BATS_MOCK_REAL_rm" -f "${BATS_MOCK_TMPDIR}/${program}-stub-plan" "${BATS_MOCK_TMPDIR}/${program}-stub-run" "${BATS_MOCK_TMPDIR}/${program}-stub-errors"
  # Delete all empty folders but don't fail
  { "$BATS_MOCK_REAL_find" "${BATS_MOCK_TMPDIR}" -type d -empty -delete || true; } &> /dev/null
  return "$STATUS"
}

stub_reset() {
  # Simply remove the whole folder
  # That deletes all stubs, plans etc.
  "$BATS_MOCK_REAL_rm" -rf "${BATS_MOCK_TMPDIR}" || true
}

unstub_all() {
  local result=0
  if [ -d "${BATS_MOCK_BINDIR}" ]; then
    for program in "${BATS_MOCK_BINDIR}"/*; do
      program=$("${BATS_MOCK_REAL_basename}" "${program}")
      unstub "${program}" || result=1
    done
  fi
  return $result
}
