"""Solar calculation utilities for sunrise/sunset times."""

from datetime import date as dt_date
from typing import Dict, Optional
from astral import LocationInfo
from astral.sun import sun

from ..models import Position
from veaf_libs.logger import logger


class SolarCalculator:
    """Calculate sunrise/sunset times for a given location."""
    
    @staticmethod
    def get_sun_times(
        position: Position,
        target_date: Optional[dt_date] = None
    ) -> Dict[str, int]:
        """
        Calculate sunrise/sunset in DCS seconds format.
        
        Args:
            position: Geographic position with latitude, longitude, timezone
            target_date: Date to calculate for (defaults to today)
        
        Returns:
            Dictionary with "sunrise" and "sunset" keys containing seconds since midnight
        """
        if not target_date:
            target_date = dt_date.today()
        
        try:
            loc = LocationInfo(
                latitude=position.latitude,
                longitude=position.longitude,
                timezone=position.timezone
            )
            
            times = sun(loc.observer, date=target_date)
            
            sunrise = times["sunrise"]
            sunset = times["sunset"]
            
            sunrise_seconds = sunrise.hour * 3600 + sunrise.minute * 60 + sunrise.second
            sunset_seconds = sunset.hour * 3600 + sunset.minute * 60 + sunset.second
            
            result = {
                "sunrise": sunrise_seconds,
                "sunset": sunset_seconds
            }
            
            logger.debug(
                f"Solar times for {position.latitude},{position.longitude}: "
                f"sunrise={sunrise_seconds}s ({sunrise.hour:02d}:{sunrise.minute:02d}), "
                f"sunset={sunset_seconds}s ({sunset.hour:02d}:{sunset.minute:02d})"
            )
            
            return result
        
        except Exception as e:
            logger.error(f"Failed to calculate solar times: {e}")
            raise
