/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// ALT Mobile: страница «NFC». Вся работа в службе пользователя alt-nfc
// (ru.altlinux.Nfc на шине сеанса, system/nfc/alt-nfc.py), страница только
// показывает её состояние и историю меток и переключает NFC.

#include <KPluginFactory>
#include <KQuickConfigModule>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QJsonDocument>

static const QString service = QStringLiteral("ru.altlinux.Nfc");
static const QString path = QStringLiteral("/ru/altlinux/Nfc");
static const QString iface = QStringLiteral("ru.altlinux.Nfc");

class AltNfcKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool locked READ locked NOTIFY stateChanged)
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)

public:
    AltNfcKcm(QObject *parent, const KPluginMetaData &data)
        : KQuickConfigModule(parent, data)
    {
        setButtons(NoAdditionalButton);
        auto bus = QDBusConnection::sessionBus();
        bus.connect(service, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"), this, SLOT(refresh()));
        bus.connect(service, path, iface, QStringLiteral("TagSeen"), this, SLOT(refreshHistory()));
        refresh();
        refreshHistory();
    }

    bool enabled() const { return m_props.value(QStringLiteral("Enabled")).toBool(); }
    bool available() const { return m_props.value(QStringLiteral("Available")).toBool(); }
    bool locked() const { return m_props.value(QStringLiteral("Locked")).toBool(); }
    bool running() const { return m_running; }
    QVariantList history() const { return m_history; }

    Q_INVOKABLE void setEnabled(bool value)
    {
        QDBusInterface(service, path, iface).asyncCall(QStringLiteral("SetEnabled"), value);
    }

    Q_INVOKABLE void clearHistory()
    {
        QDBusInterface(service, path, iface).call(QStringLiteral("ClearHistory"));
        refreshHistory();
    }

Q_SIGNALS:
    void stateChanged();
    void historyChanged();

private Q_SLOTS:
    void refresh()
    {
        auto msg = QDBusMessage::createMethodCall(service, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("GetAll"));
        msg << iface;
        auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
            w->deleteLater();
            QDBusPendingReply<QVariantMap> reply = *w;
            m_running = !reply.isError();
            m_props = reply.isError() ? QVariantMap() : reply.value();
            Q_EMIT stateChanged();
        });
    }

    void refreshHistory()
    {
        auto watcher = new QDBusPendingCallWatcher(QDBusInterface(service, path, iface).asyncCall(QStringLiteral("GetHistory")), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
            w->deleteLater();
            QDBusPendingReply<QString> reply = *w;
            m_history = reply.isError() ? QVariantList() : QJsonDocument::fromJson(reply.value().toUtf8()).toVariant().toList();
            Q_EMIT historyChanged();
        });
    }

private:
    QVariantMap m_props;
    QVariantList m_history;
    bool m_running = false;
};

K_PLUGIN_CLASS_WITH_JSON(AltNfcKcm, "kcm_altnfc.json")

#include "kcm.moc"
