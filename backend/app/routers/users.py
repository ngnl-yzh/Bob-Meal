"""회원가입 / 로그인 / 기록 / 찜"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models import User, VisitHistory, Favorite, Restaurant
from app.schemas import (
    UserRegisterIn, UserLoginIn, UserOut, TokenOut,
    RestaurantCardOut,
)
from app.services.auth_service import (
    hash_password, verify_password,
    create_access_token, require_current_user,
)
import json

router = APIRouter(prefix="/api/user", tags=["사용자"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED,
             summary="회원가입")
def register(body: UserRegisterIn, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == body.email).first():
        raise HTTPException(status_code=400, detail="이미 사용 중인 이메일입니다")
    user = User(
        email=body.email,
        hashed_password=hash_password(body.password),
        nickname=body.nickname,
        identity=body.identity.value,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=TokenOut, summary="로그인")
def login(body: UserLoginIn, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == body.email).first()
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 잘못됐습니다")
    token = create_access_token({"sub": str(user.id)})
    return TokenOut(
        access_token=token,
        user=UserOut(
            id=user.id, email=user.email,
            nickname=user.nickname, identity=user.identity,
            is_active=user.is_active,
        ),
    )


@router.get("/me", response_model=UserOut, summary="내 정보")
def get_me(current_user: User = Depends(require_current_user)):
    return current_user


@router.get("/history", summary="방문 기록")
def get_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
):
    histories = (
        db.query(VisitHistory)
        .filter(VisitHistory.user_id == current_user.id)
        .order_by(VisitHistory.visited_at.desc())
        .limit(50)
        .all()
    )
    result = []
    for h in histories:
        r = db.query(Restaurant).filter(Restaurant.id == h.restaurant_id).first()
        if r:
            result.append({
                "restaurant_id": r.id,
                "name": r.name,
                "category": r.category,
                "photo_url": r.photo_url,
                "visited_at": h.visited_at.isoformat() if h.visited_at else "",
                "rating_given": h.rating_given,
            })
    return result


@router.post("/history/{restaurant_id}", status_code=status.HTTP_201_CREATED,
             summary="방문 기록 추가")
def add_history(
    restaurant_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
):
    if not db.query(Restaurant).filter(Restaurant.id == restaurant_id).first():
        raise HTTPException(status_code=404, detail="식당을 찾을 수 없습니다")
    db.add(VisitHistory(user_id=current_user.id, restaurant_id=restaurant_id))
    db.commit()
    return {"message": "방문 기록이 저장됐습니다"}


@router.get("/favorites", summary="찜 목록")
def get_favorites(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
):
    favs = (
        db.query(Favorite)
        .filter(Favorite.user_id == current_user.id)
        .all()
    )
    result = []
    for f in favs:
        r = db.query(Restaurant).filter(Restaurant.id == f.restaurant_id).first()
        if r:
            result.append({
                "restaurant_id": r.id,
                "name": r.name,
                "category": r.category,
                "rating": r.rating,
                "photo_url": r.photo_url,
                "tags": json.loads(r.tags or "[]"),
            })
    return result


@router.post("/favorites/{restaurant_id}", status_code=status.HTTP_201_CREATED,
             summary="찜 추가")
def add_favorite(
    restaurant_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
):
    if not db.query(Restaurant).filter(Restaurant.id == restaurant_id).first():
        raise HTTPException(status_code=404, detail="식당을 찾을 수 없습니다")
    existing = db.query(Favorite).filter(
        Favorite.user_id == current_user.id,
        Favorite.restaurant_id == restaurant_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 찜한 식당입니다")
    db.add(Favorite(user_id=current_user.id, restaurant_id=restaurant_id))
    db.commit()
    return {"message": "찜 목록에 추가됐습니다"}


@router.delete("/favorites/{restaurant_id}", summary="찜 해제")
def remove_favorite(
    restaurant_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
):
    fav = db.query(Favorite).filter(
        Favorite.user_id == current_user.id,
        Favorite.restaurant_id == restaurant_id,
    ).first()
    if not fav:
        raise HTTPException(status_code=404, detail="찜 목록에 없는 식당입니다")
    db.delete(fav)
    db.commit()
    return {"message": "찜이 해제됐습니다"}
