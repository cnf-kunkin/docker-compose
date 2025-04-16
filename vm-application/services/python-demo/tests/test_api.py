from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

def test_create_item():
    item = {"name": "test", "value": 123}
    response = client.post("/api/v1/items", json=item)
    assert response.status_code == 200
    assert response.json()["status"] == "success"

def test_get_items():
    response = client.get("/api/v1/items")
    assert response.status_code == 200
    assert "items" in response.json()