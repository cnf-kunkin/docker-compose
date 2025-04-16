from fastapi import APIRouter, HTTPException
from typing import List, Dict

router = APIRouter()

# 간단한 메모리 저장소
items: List[Dict] = []

@router.get("/items")
async def get_items():
    return {"items": items}

@router.post("/items")
async def create_item(item: Dict):
    items.append(item)
    return {"status": "success", "item": item}

@router.get("/items/{item_id}")
async def get_item(item_id: int):
    if item_id < 0 or item_id >= len(items):
        raise HTTPException(status_code=404, detail="Item not found")
    return {"item": items[item_id]}