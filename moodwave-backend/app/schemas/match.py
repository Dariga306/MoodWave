from pydantic import BaseModel
from typing import Literal


class DecisionRequest(BaseModel):
    decision: Literal["like", "skip"]
