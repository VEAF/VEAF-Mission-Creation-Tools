"""Base worker abstract class for all VEAF tool workers."""

from abc import ABC, abstractmethod


class BaseWorker(ABC):
    """Abstract base for all VEAF worker classes.

    Every worker encapsulates one tool operation (build, inject, extract, …).
    Subclasses must implement :meth:`work`; all other initialisation is done
    in ``__init__``.
    """

    @abstractmethod
    def work(self) -> object:
        """Execute the worker's operation.

        Returns whatever is relevant for the concrete worker (a ``Path``, a
        list of paths, ``None``, …).  The return type is intentionally kept as
        ``object`` here so that subclasses can declare a more precise type
        without violating the Liskov Substitution Principle.
        """
