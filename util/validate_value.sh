#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash gnused yq yajsv ncurses bc
. ./prelude

set -eu

logger_trace 'util/validate_value.sh'

value="$1"
format="$2"
minValue="${3%% }"
maxValue="${4%% }"
minStep="${5%% }"
maxLen="${6%% }"
maxDataLen="${7%% }"
validValues="${8%% }"

case $format in
  bool)
    if [ "$value" != 'true' ] && [ "$value" != 'false' ] && [ "$value" != '0' ] && [ "$value" != '1' ]; then
      logger_error "Value '$value' is not a boolean"
      exit 1
    fi
    ;;
  string)
    maxLen=${maxLen:-64}
    if [ "${maxLen%% }" != "" ] && [ "${#value}" -gt "$maxLen" ]; then
      logger_error "Value '$value' is longer than maxLen $maxLen"
      exit 1
    fi
    ;;
  int | uint8 | uint16 | uint32 | uint64)
    case ${value#-} in
      ''|*[!0-9]*)
        logger_error "Value '$value' is not an integer"
        exit 1
        ;;
    esac

    case $format in
      int)
        minValue=${minValue:--2147483648}
        maxValue=${maxValue:-2147483647}
        ;;
      uint8)
        minValue=${minValue:-0}
        maxValue=${maxValue:-255}
        ;;
      uint16)
        minValue=${minValue:-0}
        maxValue=${maxValue:-65535}
        ;;
      uint32)
        minValue=${minValue:-0}
        maxValue=${maxValue:-4294967295}
        ;;
      uint64)
        minValue=${minValue:-0}
        maxValue=${maxValue:-18446744073709551615}
        ;;
    esac

    if [ "$minValue" != "" ] && [ "$value" -lt "$minValue" ]; then
      logger_error "Value '$value' is less than minValue $minValue"
      exit 1
    elif [ "$maxValue" != "" ] && [ "$value" -gt "$maxValue" ]; then
      logger_error "Value '$value' is greater than maxValue $maxValue"
      exit 1
    elif [ "$minStep" != "" ] && [ "$(echo "($value - $minValue) % $minStep" | bc)" != "0" ]; then
      logger_error "Value '$value' is not a multiple of minStep $minStep"
      exit 1
    elif [ "$validValues" != "" ] && ! { echo "$validValues" | tr ',' '\n' | grep "^$value\$" >/dev/null; }; then
      logger_error "Value '$value' is not in valid-values $validValues"
      exit 1
    fi
    ;;
  float)
    case ${value#-} in
      ''|*[!0-9]*[!0-9]*)
        logger_error "Value '$value' is not a float"
        exit 1
        ;;
      *)
    esac
    ;;
  tlv8)
    if ! { echo "$value" | ./util/tlv_decode.sh; }; then
      logger_error "Value '$value' is not a valid TLV8"
      exit 1
    fi
    ;;
  data)
    maxDataLen=${maxDataLen:-2097152}
    if [ "${#value}" -gt "$maxDataLen" ]; then
      logger_error "Value '$value' is longer than maxDataLen $maxDataLen"
      exit 1
    elif ! { echo "$value" | base64 -d >/dev/null; }; then
      logger_error "Value '$value' is not a valid base64 encoded data"
      exit 1
    fi
    ;;
  *)
    logger_warn "Unknown format $format, skipping validation for value '$value'"
    ;;
esac
