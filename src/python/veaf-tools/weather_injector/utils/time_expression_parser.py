"""Time expression parser for moment definitions."""

import ast
import operator
from collections.abc import Callable

from veaf_libs.i18n import t
from veaf_libs.logger import logger

# Whitelisted arithmetic operators. Exponentiation is intentionally excluded:
# it allows building gigantic numbers (e.g. ``2**10**9``) and is a DoS vector.
_BIN_OPS: dict[type[ast.operator], Callable[[float, float], float]] = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
}
_UNARY_OPS: dict[type[ast.unaryop], Callable[[float], float]] = {
    ast.UAdd: operator.pos,
    ast.USub: operator.neg,
}

# Conservative bounds to avoid resource exhaustion on adversarial mission data
# (e.g. a very long or deeply nested expression). Time expressions are tiny.
_MAX_EXPRESSION_LENGTH = 256
_MAX_AST_DEPTH = 32


def _safe_arithmetic_eval(expression: str) -> float:
    """Evaluate a pure arithmetic expression without executing arbitrary code.

    Only numeric literals, parentheses, the binary operators ``+ - * / // %`` and
    unary ``+``/``-`` are accepted. Names, attribute access, function calls and
    exponentiation are rejected, which removes both the code-execution and the
    DoS (huge-power) risks of ``eval``. The input length and AST depth are
    additionally bounded to limit resource exhaustion on adversarial input.

    Args:
        expression: The arithmetic expression to evaluate.

    Returns:
        The numeric result.

    Raises:
        ValueError: If the expression contains a disallowed construct, or
            exceeds the length / nesting-depth bounds.
        SyntaxError: If the expression is not valid Python arithmetic syntax.
    """
    if len(expression) > _MAX_EXPRESSION_LENGTH:
        raise ValueError(f"expression too long (> {_MAX_EXPRESSION_LENGTH} characters)")

    def _eval(node: ast.AST, depth: int) -> float:
        if depth > _MAX_AST_DEPTH:
            raise ValueError(f"expression too deeply nested (> {_MAX_AST_DEPTH})")
        if isinstance(node, ast.Expression):
            return _eval(node.body, depth + 1)
        if isinstance(node, ast.Constant):
            if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
                raise ValueError(f"unsupported constant: {node.value!r}")
            return node.value
        if isinstance(node, ast.BinOp):
            op = _BIN_OPS.get(type(node.op))
            if op is None:
                raise ValueError(f"unsupported operator: {type(node.op).__name__}")
            return op(_eval(node.left, depth + 1), _eval(node.right, depth + 1))
        if isinstance(node, ast.UnaryOp):
            unary = _UNARY_OPS.get(type(node.op))
            if unary is None:
                raise ValueError(f"unsupported unary operator: {type(node.op).__name__}")
            return unary(_eval(node.operand, depth + 1))
        raise ValueError(f"unsupported expression element: {type(node).__name__}")

    return _eval(ast.parse(expression, mode="eval"), 0)


class TimeExpressionParser:
    """Parse time expressions into seconds since midnight."""

    @staticmethod
    def parse(expression: str, sunrise_seconds: int | None = None, sunset_seconds: int | None = None) -> int:
        """
        Parse time expression to seconds since midnight.

        Supports:
        - "HH:MM" format: "02:00" → 7200
        - "sunrise" / "sunset" keywords (requires solar_times)
        - Mathematical expressions: "sunrise+30*60" → sunrise_seconds + 1800
        - Direct numbers: 54000

        Args:
            expression: Time expression string
            sunrise_seconds: Pre-calculated sunrise time (required if "sunrise" used)
            sunset_seconds: Pre-calculated sunset time (required if "sunset" used)

        Returns:
            Time in seconds since midnight (0-86400)

        Raises:
            ValueError: If expression is invalid or requires unavailable data
        """
        expr = expression.strip()

        # Simple HH:MM format
        if ":" in expr and all(c.isdigit() or c == ":" for c in expr):
            try:
                parts = expr.split(":")
                hours = int(parts[0])
                minutes = int(parts[1]) if len(parts) > 1 else 0

                if not (0 <= hours <= 23 and 0 <= minutes <= 59):
                    raise ValueError(f"Invalid hours or minutes: {hours:02d}:{minutes:02d}")

                result = hours * 3600 + minutes * 60
                logger.debug(f"Parsed time expression '{expr}' = {result}s")
                return result
            except (ValueError, IndexError) as e:
                logger.error(t("weather.time_parser.parse_failed", expr=expr, error=str(e)), exception_type=None)
                raise ValueError(f"Invalid time format '{expr}': {e}") from e

        # Replace solar references
        if "sunrise" in expr and sunrise_seconds is None:
            raise ValueError(
                "Time expression contains 'sunrise' but solar times not calculated. Add 'position' to configuration."
            )
        if "sunset" in expr and sunset_seconds is None:
            raise ValueError(
                "Time expression contains 'sunset' but solar times not calculated. Add 'position' to configuration."
            )

        if sunrise_seconds is not None:
            expr = expr.replace("sunrise", str(sunrise_seconds))
        if sunset_seconds is not None:
            expr = expr.replace("sunset", str(sunset_seconds))

        # Evaluate mathematical expression
        try:
            # AST-based arithmetic evaluator — no code execution, no DoS power op
            result = int(_safe_arithmetic_eval(expr))

            # Clamp to valid DCS time range
            result = max(0, min(86400, result))

            logger.debug(f"Parsed time expression '{expression}' = {result}s")
            return result

        except Exception as e:
            logger.error(t("weather.time_parser.eval_failed", expression=expression, error=str(e)), exception_type=None)
            raise ValueError(f"Invalid time expression '{expression}': {e}")
