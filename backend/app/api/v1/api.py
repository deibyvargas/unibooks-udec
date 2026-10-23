from fastapi import APIRouter
from app.api.v1 import (
    auth,
    sedes,
    publications,
    trades,
    transactions,
    ratings,
    chats,
    notifications
)

api_router = APIRouter()

api_router.include_router(auth.router)
api_router.include_router(sedes.router)
api_router.include_router(publications.router)
api_router.include_router(trades.router)
api_router.include_router(transactions.router)
api_router.include_router(ratings.router)
api_router.include_router(chats.router)
api_router.include_router(notifications.router)
