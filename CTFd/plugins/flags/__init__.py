import re

from CTFd.plugins import register_plugin_assets_directory
from CTFd.utils.logging import log

class FlagException(Exception):
    def __init__(self, message):
        self.message = message

    def __str__(self):
        return self.message


class BaseFlag(object):
    name = None
    templates = {}

    @staticmethod
    def compare(self, saved, provided):
        return True


class CTFdStaticFlag(BaseFlag):
    name = "static"
    templates = {  # Nunjucks templates used for key editing & viewing
        "create": "/plugins/flags/assets/static/create.html",
        "update": "/plugins/flags/assets/static/edit.html",
    }

    @staticmethod
    def compare(chal_key_obj, provided):
        saved = chal_key_obj.content
        data = chal_key_obj.data

        if len(saved) != len(provided):
            return False
        result = 0

        if data == "case_insensitive":
            for x, y in zip(saved.lower(), provided.lower()):
                result |= ord(x) ^ ord(y)
        else:
            for x, y in zip(saved, provided):
                result |= ord(x) ^ ord(y)
        return result == 0
    
    @staticmethod
    def compareteam(chal_key_obj, provided, team):
        saved = chal_key_obj.content
        data = chal_key_obj.data
        
        if "=" not in data:
            return False 
        
        print("Submitted by Team = ",team.id)
        flag_team_id = int(data.split("=")[1])
        print("FLAG TEAM ID =",flag_team_id)
        print("PROVIDED FLAG = ",provided)
        print("TABLE FLAG = ",saved)

        if len(saved) != len(provided):
            return False
        
        result = 0
        
        for x, y in zip(saved, provided):
            result |= ord(x) ^ ord(y)
        
      
        if result == 0 and flag_team_id != team.id:
            log(
                "submissions",
                "Possible cheating. Cheater Team - {team} Submitted Team {flag_team_id} flag.",
                team=team.id, flag_team_id = flag_team_id,
            )
            return False
        
        if result == 0 and flag_team_id == team.id:
            return True
        
        return False


class CTFdRegexFlag(BaseFlag):
    name = "regex"
    templates = {  # Nunjucks templates used for key editing & viewing
        "create": "/plugins/flags/assets/regex/create.html",
        "update": "/plugins/flags/assets/regex/edit.html",
    }

    @staticmethod
    def compare(chal_key_obj, provided):
        saved = chal_key_obj.content
        data = chal_key_obj.data

        try:
            if data == "case_insensitive":
                res = re.match(saved, provided, re.IGNORECASE)
            else:
                res = re.match(saved, provided)
        # TODO: this needs plugin improvements. See #1425.
        except re.error as e:
            raise FlagException("Regex parse error occured") from e

        return res and res.group() == provided


FLAG_CLASSES = {"static": CTFdStaticFlag, "regex": CTFdRegexFlag}


def get_flag_class(class_id):
    cls = FLAG_CLASSES.get(class_id)
    if cls is None:
        raise KeyError
    return cls


def load(app):
    register_plugin_assets_directory(app, base_path="/plugins/flags/assets/")
