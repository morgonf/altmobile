/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// ALT Mobile: «Тема и обои». Светлая или тёмная схема ALT Mobile и обои
// рабочего стола и экрана блокировки. Обои выбираются с предпросмотром и
// ставятся только явной кнопкой (setWallpaper), случайное касание ничего
// не записывает.

#include <KConfigGroup>
#include <KLocalizedString>
#include <KPluginFactory>
#include <KQuickConfigModule>
#include <KSharedConfig>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

class AltAppearanceKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(bool dark READ dark NOTIFY schemeChanged)
    // Установленные глобальные темы: id, name, preview, scheme, current
    Q_PROPERTY(QVariantList themes READ themes NOTIFY themesChanged)
    Q_PROPERTY(QVariantList wallpapers READ wallpapers NOTIFY wallpapersChanged)
    Q_PROPERTY(QString homeWallpaper READ homeWallpaper NOTIFY wallpaperChanged)
    Q_PROPERTY(QString lockWallpaper READ lockWallpaper NOTIFY wallpaperChanged)

public:
    AltAppearanceKcm(QObject *parent, const KPluginMetaData &data)
        : KQuickConfigModule(parent, data)
    {
        setButtons(NoAdditionalButton);
        scanWallpapers();
        scanThemes();
    }

    QVariantList themes() const
    {
        return m_themes;
    }

    // Глобальная тема целиком (цвета, значки, шрифты) с сохранением обоев:
    // plasma-apply-lookandfeel ставит и обои темы, их возвращаем после
    Q_INVOKABLE void applyTheme(const QString &id)
    {
        const QString home = currentImage(QStringLiteral("home"));
        const QString lock = currentImage(QStringLiteral("lock"));
        QString scheme;
        for (const QVariant &v : std::as_const(m_themes)) {
            if (v.toMap().value(QStringLiteral("id")) == id) {
                scheme = v.toMap().value(QStringLiteral("scheme")).toString();
            }
        }
        auto process = new QProcess(this);
        connect(process, &QProcess::finished, this, [this, process, home, lock, scheme]() {
            process->deleteLater();
            if (!home.isEmpty()) {
                setWallpaper(home, true, false);
            }
            if (!lock.isEmpty()) {
                setWallpaper(lock, false, true);
            }
            // Приложения GTK и libadwaita: тёмный или светлый вид по схеме
            QProcess::startDetached(QStringLiteral("gsettings"),
                                    {QStringLiteral("set"), QStringLiteral("org.gnome.desktop.interface"), QStringLiteral("color-scheme"),
                                     scheme.contains(QLatin1String("Dark")) ? QStringLiteral("prefer-dark") : QStringLiteral("default")});
            scanThemes();
            Q_EMIT schemeChanged();
        });
        process->start(QStringLiteral("plasma-apply-lookandfeel"), {QStringLiteral("--apply"), id});
    }

    // Тема из архива (.tar.gz, .zip) в ~/.local/share/plasma/look-and-feel
    Q_INVOKABLE void installTheme(const QUrl &url)
    {
        auto process = new QProcess(this);
        connect(process, &QProcess::finished, this, [this, process]() {
            process->deleteLater();
            scanThemes();
        });
        process->start(QStringLiteral("kpackagetool6"),
                       {QStringLiteral("--type"), QStringLiteral("Plasma/LookAndFeel"), QStringLiteral("--install"), url.toLocalFile()});
    }

    // После загрузки из KDE Store
    Q_INVOKABLE void rescan()
    {
        scanThemes();
        scanWallpapers();
    }

    bool dark() const
    {
        KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
        config->reparseConfiguration();
        return KConfigGroup(config, QStringLiteral("General")).readEntry("ColorScheme") != QLatin1String("ALTMobile");
    }

    QVariantList wallpapers() const
    {
        return m_wallpapers;
    }

    // Превью текущих обоев (путь к картинке)
    QString homeWallpaper() const
    {
        KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("plasma-org.kde.plasma.mobileshell-appletsrc"));
        config->reparseConfiguration();
        const KConfigGroup containments(config, QStringLiteral("Containments"));
        for (const QString &id : containments.groupList()) {
            const KConfigGroup general = containments.group(id).group(QStringLiteral("Wallpaper")).group(QStringLiteral("org.kde.image")).group(QStringLiteral("General"));
            const QString image = general.readEntry("Image");
            if (!image.isEmpty()) {
                return previewFor(image);
            }
        }
        return QString();
    }

    QString lockWallpaper() const
    {
        KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
        config->reparseConfiguration();
        const KConfigGroup general =
            KConfigGroup(config, QStringLiteral("Greeter")).group(QStringLiteral("Wallpaper")).group(QStringLiteral("org.kde.image")).group(QStringLiteral("General"));
        return previewFor(general.readEntry("Image"));
    }

    Q_INVOKABLE void setDark(bool dark)
    {
        auto process = new QProcess(this);
        connect(process, &QProcess::finished, this, [this, process]() {
            process->deleteLater();
            scanThemes();
            Q_EMIT schemeChanged();
        });
        process->start(QStringLiteral("/usr/libexec/alt-mobile/set-color-scheme"), {dark ? QStringLiteral("dark") : QStringLiteral("light")});
    }

    // source: путь к пакету обоев (каталог) или к картинке
    Q_INVOKABLE void setWallpaper(const QString &source, bool home, bool lock)
    {
        if (home) {
            auto process = new QProcess(this);
            connect(process, &QProcess::finished, this, [this, process]() {
                process->deleteLater();
                Q_EMIT wallpaperChanged();
            });
            process->start(QStringLiteral("plasma-apply-wallpaperimage"), {source});
        }
        if (lock) {
            KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
            KConfigGroup greeter(config, QStringLiteral("Greeter"));
            greeter.writeEntry("WallpaperPlugin", QStringLiteral("org.kde.image"));
            KConfigGroup general = greeter.group(QStringLiteral("Wallpaper")).group(QStringLiteral("org.kde.image")).group(QStringLiteral("General"));
            QString url = QUrl::fromLocalFile(source).toString();
            if (QFileInfo(source).isDir() && !url.endsWith(QLatin1Char('/'))) {
                url += QLatin1Char('/');
            }
            general.writeEntry("Image", url);
            general.writeEntry("PreviewImage", url);
            config->sync();
            QDBusConnection::sessionBus().asyncCall(
                QDBusMessage::createMethodCall(QStringLiteral("org.kde.screensaver"), QStringLiteral("/ScreenSaver"), QStringLiteral("org.kde.screensaver"), QStringLiteral("configure")));
            Q_EMIT wallpaperChanged();
        }
    }

    // Картинка из файлов: копия в ~/.local/share/wallpapers, затем в списке
    Q_INVOKABLE QString addWallpaper(const QUrl &url)
    {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/wallpapers");
        QDir().mkpath(dir);
        const QString target = dir + QLatin1Char('/') + url.fileName();
        if (!QFile::exists(target) && !QFile::copy(url.toLocalFile(), target)) {
            return QString();
        }
        scanWallpapers();
        return target;
    }

Q_SIGNALS:
    void schemeChanged();
    void themesChanged();
    void wallpapersChanged();
    void wallpaperChanged();

private:
    // Источник текущих обоев (путь к пакету или картинке) для home или lock
    QString currentImage(const QString &where) const
    {
        QString image;
        if (where == QLatin1String("lock")) {
            KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
            config->reparseConfiguration();
            image = KConfigGroup(config, QStringLiteral("Greeter"))
                        .group(QStringLiteral("Wallpaper"))
                        .group(QStringLiteral("org.kde.image"))
                        .group(QStringLiteral("General"))
                        .readEntry("Image");
        } else {
            KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("plasma-org.kde.plasma.mobileshell-appletsrc"));
            config->reparseConfiguration();
            const KConfigGroup containments(config, QStringLiteral("Containments"));
            for (const QString &id : containments.groupList()) {
                image = containments.group(id).group(QStringLiteral("Wallpaper")).group(QStringLiteral("org.kde.image")).group(QStringLiteral("General")).readEntry("Image");
                if (!image.isEmpty()) {
                    break;
                }
            }
        }
        QString path = image.startsWith(QLatin1String("file://")) ? QUrl(image).toLocalFile() : image;
        if (path.endsWith(QLatin1Char('/'))) {
            path.chop(1);
        }
        return path;
    }

    void scanThemes()
    {
        KSharedConfig::Ptr globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
        globals->reparseConfiguration();
        const QString currentScheme = KConfigGroup(globals, QStringLiteral("General")).readEntry("ColorScheme");
        const QString currentIcons = KConfigGroup(globals, QStringLiteral("Icons")).readEntry("Theme", QStringLiteral("breeze"));
        QVariantList alt, other;
        QSet<QString> seen;
        const QStringList dirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("plasma/look-and-feel"), QStandardPaths::LocateDirectory);
        for (const QString &base : dirs) {
            for (const QFileInfo &info : QDir(base).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
                if (seen.contains(info.fileName()) || !QFile::exists(info.filePath() + QStringLiteral("/metadata.json"))) {
                    continue;
                }
                seen << info.fileName();
                const KConfig defaults(info.filePath() + QStringLiteral("/contents/defaults"), KConfig::SimpleConfig);
                const KConfigGroup kdeglobals(&defaults, QStringLiteral("kdeglobals"));
                const QString scheme = kdeglobals.group(QStringLiteral("General")).readEntry("ColorScheme");
                const QString icons = kdeglobals.group(QStringLiteral("Icons")).readEntry("Theme", QStringLiteral("breeze"));
                QString preview = info.filePath() + QStringLiteral("/contents/previews/fullscreenpreview.jpg");
                if (!QFile::exists(preview)) {
                    preview = info.filePath() + QStringLiteral("/contents/previews/preview.png");
                }
                const QVariantMap item{
                    {QStringLiteral("id"), info.fileName()},
                    {QStringLiteral("name"), packageName(info.filePath())},
                    {QStringLiteral("preview"), QFile::exists(preview) ? preview : QString()},
                    {QStringLiteral("scheme"), scheme},
                    {QStringLiteral("current"), scheme == currentScheme && icons == currentIcons},
                };
                (info.fileName().startsWith(QLatin1String("org.altlinux")) ? alt : other) << item;
            }
        }
        m_themes = alt + other;
        Q_EMIT themesChanged();
    }

    static bool isImage(const QString &name)
    {
        static const QStringList suffixes{QStringLiteral("jpg"), QStringLiteral("jpeg"), QStringLiteral("png"), QStringLiteral("webp"), QStringLiteral("avif"), QStringLiteral("jxl")};
        return suffixes.contains(QFileInfo(name).suffix().toLower());
    }

    // Картинка для показа: у пакета снимок или самое большое изображение
    static QString packagePreview(const QString &dir)
    {
        const QDir contents(dir + QStringLiteral("/contents"));
        for (const QString &name : contents.entryList({QStringLiteral("screenshot.*")}, QDir::Files)) {
            return contents.filePath(name);
        }
        QString best;
        qint64 bestSize = -1;
        const QDir images(dir + QStringLiteral("/contents/images"));
        for (const QFileInfo &info : images.entryInfoList(QDir::Files)) {
            if (isImage(info.fileName()) && info.size() > bestSize) {
                best = info.filePath();
                bestSize = info.size();
            }
        }
        return best;
    }

    static QString previewFor(const QString &image)
    {
        if (image.isEmpty()) {
            return QString();
        }
        QString path = image.startsWith(QLatin1String("file://")) ? QUrl(image).toLocalFile() : image;
        if (!path.startsWith(QLatin1Char('/'))) {
            path = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("wallpapers/") + path, QStandardPaths::LocateDirectory);
        }
        if (path.endsWith(QLatin1Char('/'))) {
            path.chop(1);
        }
        return QFileInfo(path).isDir() ? packagePreview(path) : path;
    }

    static QString packageName(const QString &dir)
    {
        QFile file(dir + QStringLiteral("/metadata.json"));
        if (!file.open(QIODevice::ReadOnly)) {
            return QFileInfo(dir).fileName();
        }
        const QJsonObject plugin = QJsonDocument::fromJson(file.readAll()).object().value(QStringLiteral("KPlugin")).toObject();
        const QString ru = plugin.value(QStringLiteral("Name[ru]")).toString();
        return ru.isEmpty() ? plugin.value(QStringLiteral("Name")).toString() : ru;
    }

    void scanWallpapers()
    {
        m_wallpapers.clear();
        const QStringList dirs = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("wallpapers"), QStandardPaths::LocateDirectory);
        // ALT первыми
        QVariantList alt, other;
        for (const QString &base : dirs) {
            const QDir dir(base);
            for (const QFileInfo &info : dir.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::Name)) {
                QVariantMap item;
                if (info.isDir() && QFile::exists(info.filePath() + QStringLiteral("/metadata.json"))) {
                    item[QStringLiteral("source")] = info.filePath();
                    item[QStringLiteral("preview")] = packagePreview(info.filePath());
                    item[QStringLiteral("name")] = packageName(info.filePath());
                } else if (info.isDir()) {
                    // Каталог картинок без пакета (wallpapers-mobile)
                    for (const QFileInfo &file : QDir(info.filePath()).entryInfoList(QDir::Files, QDir::Name)) {
                        if (isImage(file.fileName())) {
                            other << QVariantMap{{QStringLiteral("source"), file.filePath()},
                                                 {QStringLiteral("preview"), file.filePath()},
                                                 {QStringLiteral("name"), file.completeBaseName()}};
                        }
                    }
                    continue;
                } else if (isImage(info.fileName())) {
                    item[QStringLiteral("source")] = info.filePath();
                    item[QStringLiteral("preview")] = info.filePath();
                    item[QStringLiteral("name")] = info.completeBaseName();
                } else {
                    continue;
                }
                (info.fileName().startsWith(QLatin1String("ALT")) ? alt : other) << item;
            }
        }
        m_wallpapers = alt + other;
        Q_EMIT wallpapersChanged();
    }

    QVariantList m_wallpapers;
    QVariantList m_themes;
};

K_PLUGIN_CLASS_WITH_JSON(AltAppearanceKcm, "kcm_altappearance.json")

#include "kcm.moc"
