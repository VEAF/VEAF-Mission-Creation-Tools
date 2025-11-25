"""Time expression parser for moment definitions."""

from typing import Optional
from veaf_libs.logger import logger


class TimeExpressionParser:
    """Parse time expressions into seconds since midnight."""
    
    @staticmethod
    def parse(
        expression: str,
        sunrise_seconds: Optional[int] = None,
        sunset_seconds: Optional[int] = None
    ) -> int:
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
                logger.error(f"Failed to parse time expression '{expr}': {e}")
                raise ValueError(f"Invalid time format '{expr}': {e}")
        
        # Replace solar references
        if "sunrise" in expr and sunrise_seconds is None:
            raise ValueError(
                "Time expression contains 'sunrise' but solar times not calculated. "
                "Add 'position' to configuration."
            )
        if "sunset" in expr and sunset_seconds is None:
            raise ValueError(
                "Time expression contains 'sunset' but solar times not calculated. "
                "Add 'position' to configuration."
            )
        
        if sunrise_seconds is not None:
            expr = expr.replace("sunrise", str(sunrise_seconds))
        if sunset_seconds is not None:
            expr = expr.replace("sunset", str(sunset_seconds))
        
        # Evaluate mathematical expression
        try:
            # Use eval with restricted namespace for safety
            result = int(eval(expr, {"__builtins__": {}}, {}))
            
            # Clamp to valid DCS time range
            result = max(0, min(86400, result))
            
            logger.debug(f"Parsed time expression '{expression}' = {result}s")
            return result
        
        except Exception as e:
            logger.error(f"Failed to evaluate time expression '{expression}': {e}")
            raise ValueError(f"Invalid time expression '{expression}': {e}")
