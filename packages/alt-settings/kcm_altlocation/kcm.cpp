/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// ALT Mobile: страница «Местоположение». Включает и выключает определение
// местоположения теми же службами, что и кнопка в шторке
// (system/plasma/quicksetting-location: alt-location-on и alt-location-off,
// запуск разрешён правилом polkit). Выключено, когда служба geoclue
// замаскирована. Программы, которые сейчас получают координаты, это
// клиенты geoclue на системной шине. Их свойства (в том числе имя
// программы) geoclue отдаёт только самой программе, поэтому видно лишь
// их число. Второй переключатель оставляет только GPS: службы
// alt-location-net-on и alt-location-net-off.

#include <KPluginFactory>
#include <KQuickConfigModule>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QDomDocument>
#include <QFile>
#include <QTimer>

static const QString systemd = QStringLiteral("org.freedesktop.systemd1");
static const QString geoclue = QStringLiteral("org.freedesktop.GeoClue2");

class AltLocationKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(int clients READ clients NOTIFY stateChanged)
    Q_PROPERTY(bool networkEnabled READ networkEnabled NOTIFY stateChanged)

public:
    AltLocationKcm(QObject *parent, const KPluginMetaData &data)
        : KQuickConfigModule(parent, data)
    {
        setButtons(NoAdditionalButton);
        m_timer.setInterval(2000);
        connect(&m_timer, &QTimer::timeout, this, &AltLocationKcm::refresh);
        m_timer.start();
        refresh();
    }

    bool enabled() const { return m_enabled; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    int clients() const { return m_clients; }
    bool networkEnabled() const { return m_networkEnabled; }

    Q_INVOKABLE void setEnabled(bool value)
    {
        startUnit(value ? QStringLiteral("alt-location-on.service") : QStringLiteral("alt-location-off.service"));
    }

    // Сетевые источники geoclue (BeaconDB по Wi-Fi и базовым станциям, IP),
    // system/plasma/quicksetting-location/alt-location-net-*.service
    Q_INVOKABLE void setNetworkEnabled(bool value)
    {
        startUnit(value ? QStringLiteral("alt-location-net-on.service") : QStringLiteral("alt-location-net-off.service"));
    }

Q_SIGNALS:
    void stateChanged();

private:
    void startUnit(const QString &name)
    {
        m_busy = true;
        m_error.clear();
        Q_EMIT stateChanged();
        QDBusMessage msg = QDBusMessage::createMethodCall(systemd, QStringLiteral("/org/freedesktop/systemd1"),
                                                          QStringLiteral("org.freedesktop.systemd1.Manager"), QStringLiteral("StartUnit"));
        msg << name << QStringLiteral("replace");
        msg.setInteractiveAuthorizationAllowed(true);
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
            watcher->deleteLater();
            QDBusPendingReply<QDBusObjectPath> reply = *watcher;
            if (reply.isError()) {
                m_error = reply.error().message();
            }
            // Служба короткая: состояние geoclue меняется через мгновение
            QTimer::singleShot(1500, this, [this]() {
                m_busy = false;
                refresh();
            });
        });
    }

private Q_SLOTS:
    void refresh()
    {
        auto bus = QDBusConnection::systemBus();
        QDBusInterface manager(systemd, QStringLiteral("/org/freedesktop/systemd1"), QStringLiteral("org.freedesktop.systemd1.Manager"), bus);
        QDBusReply<QDBusObjectPath> unit = manager.call(QStringLiteral("LoadUnit"), QStringLiteral("geoclue.service"));
        if (unit.isValid()) {
            QDBusInterface props(systemd, unit.value().path(), QStringLiteral("org.freedesktop.systemd1.Unit"), bus);
            m_enabled = props.property("UnitFileState").toString() != QLatin1String("masked");
        }

        m_networkEnabled = !QFile::exists(QStringLiteral("/etc/geoclue/conf.d/90-alt-no-network.conf"));

        // Клиенты geoclue: /org/freedesktop/GeoClue2/Client/N, пока программа
        // держит доступ к местоположению
        m_clients = 0;
        if (m_enabled) {
            QDBusMessage intro = QDBusMessage::createMethodCall(geoclue, QStringLiteral("/org/freedesktop/GeoClue2/Client"),
                                                                QStringLiteral("org.freedesktop.DBus.Introspectable"), QStringLiteral("Introspect"));
            QDBusReply<QString> xml = bus.call(intro, QDBus::Block, 2000);
            if (xml.isValid()) {
                QDomDocument doc;
                doc.setContent(xml.value());
                const QDomNodeList nodes = doc.documentElement().elementsByTagName(QStringLiteral("node"));
                for (int i = 0; i < nodes.count(); i++) {
                    if (!nodes.at(i).toElement().attribute(QStringLiteral("name")).isEmpty()) {
                        m_clients++;
                    }
                }
            }
        }
        Q_EMIT stateChanged();
    }

private:
    QTimer m_timer;
    bool m_enabled = false;
    bool m_busy = false;
    QString m_error;
    int m_clients = 0;
    bool m_networkEnabled = true;
};

K_PLUGIN_CLASS_WITH_JSON(AltLocationKcm, "kcm_altlocation.json")

#include "kcm.moc"
