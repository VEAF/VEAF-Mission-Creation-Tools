package logview

import (
	"errors"

	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/apilog"
	"github.com/VEAF/VEAF-Mission-Creation-Tools/src/go/veaf-logs/internal/logcore"
)

// ProblemText says why a journal cannot be read now, with the error's own words.
func ProblemText(err error) string {
	if err == logcore.ErrUnavailable {
		return "journal momentanément indisponible" // a local file, while DCS rotates it
	}
	if text := problemKind(err); text != "" {
		return text + " (" + err.Error() + ")"
	}
	return err.Error()
}

func problemKind(err error) string {
	switch {
	case errors.Is(err, logcore.ErrAPIAuth):
		return "authentification refusée : vérifie la clé API ; sur DCSServerBot 3.0.5, le restapi.yaml du serveur doit accepter une clé API d'où tu te connectes, sur les routes de logs et sur servers"
	case errors.Is(err, apilog.ErrNoLogRoutes):
		return "ce DCSServerBot n'a pas les routes de logs (version trop ancienne, ou pas d'api_key)"
	case errors.Is(err, logcore.ErrRemoteFileMissing):
		return "pas encore de journal sur le serveur"
	case errors.Is(err, logcore.ErrAPIUnknownLog):
		return "instance ou fichier inconnu du serveur"
	case errors.Is(err, logcore.ErrAPIOtherNode):
		return "journal sur un autre nœud : cette version du bot ne lit que les siens"
	case errors.Is(err, logcore.ErrUnavailable):
		return "serveur injoignable"
	}
	return ""
}
