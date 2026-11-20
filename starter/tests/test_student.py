"""Новые случаи: допустимая граница площади и неподдерживаемый формат."""

from io import BytesIO

import pytest
from PIL import Image
from pydantic import ValidationError

from model import MAX_IMAGE_BYTES, MAX_PIXELS, CaptionInput


def test_png_at_pixel_limit_is_valid():
    stream = BytesIO()
    Image.new("RGB", (1024, 1024), "white").save(stream, format="PNG")
    image = stream.getvalue()
    assert 1024 * 1024 == MAX_PIXELS
    assert len(image) < MAX_IMAGE_BYTES

    value = CaptionInput(image=image)

    assert value.image == image
    assert value.max_new_tokens is None


def test_valid_gif_is_rejected():
    stream = BytesIO()
    Image.new("RGB", (16, 16), "white").save(stream, format="GIF")
    # Файл исправен и мал; отказ должен быть именно из-за формата.
    with pytest.raises(ValidationError, match="Only JPEG and PNG are supported"):
        CaptionInput(image=stream.getvalue())
