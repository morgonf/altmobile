/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// ALT Mobile: страница «Хранилище». Занятое и свободное место корневой
// файловой системы и из чего оно складывается. Размеры каталогов
// считаются в отдельном потоке. «Система и программы» это всё занятое
// место за вычетом посчитанного. Кэш приложений очищается здесь же,
// скачанные пакеты удаляет помощник KAuth org.altmobile.storage.

#include <KAuth/Action>
#include <KAuth/ExecuteJob>
#include <KFormat>
#include <KPluginFactory>
#include <KQuickConfigModule>

#include <QDir>
#include <QDirIterator>
#include <QFutureWatcher>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QtConcurrent>

namespace
{
struct Category {
    QString name;
    QString icon;
    QString path;
    qint64 bytes = 0;
};

struct Usage {
    qint64 total = 0;
    qint64 free = 0;
    QList<Category> categories;
};

qint64 dirSize(const QString &path)
{
    qint64 size = 0;
    QDirIterator it(path, QDir::Files | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        const QFileInfo info = it.fileInfo();
        if (!info.isSymLink()) {
            size += info.size();
        }
    }
    return size;
}

Usage measure()
{
    Usage u;
    const QStorageInfo root(QStringLiteral("/"));
    u.total = root.bytesTotal();
    u.free = root.bytesAvailable();

    const QString home = QDir::homePath();
    auto xdg = [](QStandardPaths::StandardLocation l) {
        return QStandardPaths::writableLocation(l);
    };
    const QList<Category> user = {
        {QStringLiteral("Фото и снимки экрана"), QStringLiteral("folder-pictures"), xdg(QStandardPaths::PicturesLocation)},
        {QStringLiteral("Видео"), QStringLiteral("folder-videos"), xdg(QStandardPaths::MoviesLocation)},
        {QStringLiteral("Музыка"), QStringLiteral("folder-music"), xdg(QStandardPaths::MusicLocation)},
        {QStringLiteral("Документы"), QStringLiteral("folder-documents"), xdg(QStandardPaths::DocumentsLocation)},
        {QStringLiteral("Загрузки"), QStringLiteral("folder-download"), xdg(QStandardPaths::DownloadLocation)},
        {QStringLiteral("Кэш приложений"), QStringLiteral("edit-clear-all"), xdg(QStandardPaths::GenericCacheLocation)},
    };

    qint64 counted = 0;
    for (Category c : user) {
        // Папка XDG, указывающая на сам домашний каталог, посчиталась бы дважды
        if (c.path.isEmpty() || QDir(c.path) == QDir(home)) {
            continue;
        }
        c.bytes = dirSize(c.path);
        counted += c.bytes;
        u.categories << c;
    }
    const qint64 homeTotal = dirSize(home);
    u.categories << Category{QStringLiteral("Прочие файлы пользователя"), QStringLiteral("folder-home"), home,
                             std::max<qint64>(0, homeTotal - counted)};

    const Category journal{QStringLiteral("Журнал системы"), QStringLiteral("utilities-log-viewer"),
                           QStringLiteral("/var/log/journal"), dirSize(QStringLiteral("/var/log/journal"))};
    const Category packages{QStringLiteral("Скачанные пакеты"), QStringLiteral("package-x-generic"),
                            QStringLiteral("/var/cache/apt/archives"), dirSize(QStringLiteral("/var/cache/apt/archives"))};
    u.categories << journal << packages;

    const qint64 used = u.total - u.free;
    const qint64 system = std::max<qint64>(0, used - homeTotal - journal.bytes - packages.bytes);
    u.categories.prepend(Category{QStringLiteral("Система и программы"), QStringLiteral("computer"), QStringLiteral("/"), system});
    return u;
}
}

class AltStorageKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(qint64 total READ total NOTIFY changed)
    Q_PROPERTY(qint64 free READ free NOTIFY changed)
    Q_PROPERTY(QVariantList categories READ categories NOTIFY changed)
    Q_PROPERTY(qint64 cacheBytes READ cacheBytes NOTIFY changed)
    Q_PROPERTY(qint64 packagesBytes READ packagesBytes NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY busyChanged)

public:
    AltStorageKcm(QObject *parent, const KPluginMetaData &data)
        : KQuickConfigModule(parent, data)
    {
        setButtons(NoAdditionalButton);
        connect(&m_watcher, &QFutureWatcher<Usage>::finished, this, [this]() {
            m_usage = m_watcher.result();
            m_busy = false;
            Q_EMIT changed();
            Q_EMIT busyChanged();
        });
        refresh();
    }

    qint64 total() const { return m_usage.total; }
    qint64 free() const { return m_usage.free; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    qint64 cacheBytes() const { return bytesOf(QStringLiteral("edit-clear-all")); }
    qint64 packagesBytes() const { return bytesOf(QStringLiteral("package-x-generic")); }

    QVariantList categories() const
    {
        QVariantList list;
        for (const Category &c : m_usage.categories) {
            list << QVariantMap{{QStringLiteral("name"), c.name},
                                {QStringLiteral("icon"), c.icon},
                                {QStringLiteral("bytes"), c.bytes}};
        }
        return list;
    }

    Q_INVOKABLE QString formatSize(qint64 bytes) const
    {
        return KFormat().formatByteSize(static_cast<double>(bytes), 1, KFormat::JEDECBinaryDialect);
    }

    Q_INVOKABLE void refresh()
    {
        if (m_watcher.isRunning()) {
            return;
        }
        m_busy = true;
        Q_EMIT busyChanged();
        m_watcher.setFuture(QtConcurrent::run(measure));
    }

    // Кэш пересоздаётся приложениями сам; удаляется содержимое ~/.cache
    Q_INVOKABLE void clearCache()
    {
        m_error.clear();
        m_busy = true;
        Q_EMIT busyChanged();
        auto *watcher = new QFutureWatcher<void>(this);
        connect(watcher, &QFutureWatcher<void>::finished, this, [this, watcher]() {
            watcher->deleteLater();
            m_busy = false;
            refresh();
        });
        watcher->setFuture(QtConcurrent::run([]() {
            QDir cache(QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation));
            const auto entries = cache.entryInfoList(QDir::AllEntries | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot);
            for (const QFileInfo &e : entries) {
                if (e.isDir() && !e.isSymLink()) {
                    QDir(e.absoluteFilePath()).removeRecursively();
                } else {
                    QFile::remove(e.absoluteFilePath());
                }
            }
        }));
    }

    Q_INVOKABLE void cleanPackages()
    {
        m_error.clear();
        m_busy = true;
        Q_EMIT busyChanged();
        KAuth::Action action(QStringLiteral("org.altmobile.storage.cleanpackages"));
        action.setHelperId(QStringLiteral("org.altmobile.storage"));
        KAuth::ExecuteJob *job = action.execute();
        connect(job, &KJob::result, this, [this, job]() {
            m_busy = false;
            if (job->error() && job->error() != KAuth::ActionReply::AuthorizationDeniedError
                && job->error() != KAuth::ActionReply::UserCancelledError) {
                m_error = job->errorString().isEmpty() ? job->errorText() : job->errorString();
            }
            refresh();
        });
        job->start();
    }

Q_SIGNALS:
    void changed();
    void busyChanged();

private:
    qint64 bytesOf(const QString &icon) const
    {
        for (const Category &c : m_usage.categories) {
            if (c.icon == icon) {
                return c.bytes;
            }
        }
        return 0;
    }

    QFutureWatcher<Usage> m_watcher;
    Usage m_usage;
    bool m_busy = false;
    QString m_error;
};

K_PLUGIN_CLASS_WITH_JSON(AltStorageKcm, "kcm_altstorage.json")

#include "kcm.moc"
