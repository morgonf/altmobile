#!/bin/sh
# Программы по умолчанию под Plasma, от пользователя. Без этого картинки,
# музыку и видео открывал Firefox: своих назначений не было, и выбиралось
# первое подходящее приложение. Для фото оставлен Koko (выбор KDE-версий
# 28.09.2026), музыка Amberol, видео Light Video.
xdg-mime default org.kde.koko.desktop image/png image/jpeg image/gif image/webp image/bmp image/tiff image/heif image/avif
xdg-mime default io.bassi.Amberol.desktop audio/ogg audio/mpeg audio/flac audio/x-wav audio/wav audio/mp4 audio/x-vorbis+ogg audio/opus
xdg-mime default org.sigxcpu.Livi.desktop video/mp4 video/webm video/x-matroska video/quicktime
