/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// ALT Mobile: страница «Здоровье батареи». Износ по оценке самого датчика
// заряда (StateOfHealth, его раз в час пишет alt-battery-health в
// /run/alt-mobile/battery-health) и ограничение заряда: служба
// alt-charge-limit, её включают и выключают службы alt-charge-limit-on и
// alt-charge-limit-off (system/battery, запуск разрешён правилом polkit).

#include <KPluginFactory>
#include <KQuickConfigModule>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QFile>
#include <QTimer>

static const QString systemd = QStringLiteral("org.freedesktop.systemd1");
static const QString battery = QStringLiteral("/sys/class/power_supply/bq27411-0/");

// Файл вида KEY=значение по строкам, как /etc/alt-mobile/charge-limit
static QMap<QString, int> readValues(const QString &path)
{
    QMap<QString, int> values;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return values;
    }
    const QList<QByteArray> lines = f.readAll().split('\n');
    for (const QByteArray &line : lines) {
        const int eq = line.indexOf('=');
        if (eq > 0 && !line.startsWith('#')) {
            bool ok = false;
            const int v = line.mid(eq + 1).trimmed().toInt(&ok);
            if (ok) {
                values.insert(QString::fromLatin1(line.left(eq).trimmed()), v);
            }
        }
    }
    return values;
}

static int readInt(const QString &name)
{
    QFile f(battery + name);
    if (!f.open(QIODevice::ReadOnly)) {
        return -1;
    }
    bool ok = false;
    const int v = f.readAll().trimmed().toInt(&ok);
    return ok ? v : -1;
}

class AltBatteryKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(int health READ health NOTIFY stateChanged)
    Q_PROPERTY(int designCapacity READ designCapacity NOTIFY stateChanged)
    Q_PROPERTY(int capacity READ capacity NOTIFY stateChanged)
    Q_PROPERTY(bool limitEnabled READ limitEnabled NOTIFY stateChanged)
    Q_PROPERTY(int limit READ limit NOTIFY stateChanged)
    Q_PROPERTY(int resume READ resume NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)

public:
    AltBatteryKcm(QObject *parent, const KPluginMetaData &data)
        : KQuickConfigModule(parent, data)
    {
        setButtons(NoAdditionalButton);
        m_timer.setInterval(5000);
        connect(&m_timer, &QTimer::timeout, this, &AltBatteryKcm::refresh);
        m_timer.start();
        refresh();
    }

    int health() const { return m_health; }
    int designCapacity() const { return m_designCapacity; }
    int capacity() const { return m_capacity; }
    bool limitEnabled() const { return m_limitEnabled; }
    int limit() const { return m_limit; }
    int resume() const { return m_resume; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }

    Q_INVOKABLE void setLimitEnabled(bool value)
    {
        m_busy = true;
        m_error.clear();
        Q_EMIT stateChanged();
        QDBusMessage msg = QDBusMessage::createMethodCall(systemd, QStringLiteral("/org/freedesktop/systemd1"),
                                                          QStringLiteral("org.freedesktop.systemd1.Manager"), QStringLiteral("StartUnit"));
        msg << (value ? QStringLiteral("alt-charge-limit-on.service") : QStringLiteral("alt-charge-limit-off.service")) << QStringLiteral("replace");
        msg.setInteractiveAuthorizationAllowed(true);
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
            watcher->deleteLater();
            QDBusPendingReply<QDBusObjectPath> reply = *watcher;
            if (reply.isError()) {
                m_error = reply.error().message();
            }
            // systemctl enable внутри службы занимает пару секунд
            QTimer::singleShot(2500, this, [this]() {
                m_busy = false;
                refresh();
            });
        });
    }

Q_SIGNALS:
    void stateChanged();

private Q_SLOTS:
    void refresh()
    {
        // Оценка готова, когда датчик набрал данных (состояние 3)
        const auto soh = readValues(QStringLiteral("/run/alt-mobile/battery-health"));
        m_health = soh.value(QStringLiteral("SOH_STATUS")) == 3 ? soh.value(QStringLiteral("SOH"), -1) : -1;
        m_designCapacity = readInt(QStringLiteral("charge_full_design")) / 1000;
        m_capacity = readInt(QStringLiteral("capacity"));

        const auto conf = readValues(QStringLiteral("/etc/alt-mobile/charge-limit"));
        m_limit = conf.value(QStringLiteral("LIMIT"), 80);
        m_resume = conf.value(QStringLiteral("RESUME"), 75);

        auto bus = QDBusConnection::systemBus();
        QDBusInterface manager(systemd, QStringLiteral("/org/freedesktop/systemd1"), QStringLiteral("org.freedesktop.systemd1.Manager"), bus);
        QDBusReply<QDBusObjectPath> unit = manager.call(QStringLiteral("LoadUnit"), QStringLiteral("alt-charge-limit.service"));
        if (unit.isValid()) {
            QDBusInterface props(systemd, unit.value().path(), QStringLiteral("org.freedesktop.systemd1.Unit"), bus);
            m_limitEnabled = props.property("UnitFileState").toString() == QLatin1String("enabled");
        }
        Q_EMIT stateChanged();
    }

private:
    QTimer m_timer;
    int m_health = -1;
    int m_designCapacity = -1;
    int m_capacity = -1;
    bool m_limitEnabled = false;
    int m_limit = 80;
    int m_resume = 75;
    bool m_busy = false;
    QString m_error;
};

K_PLUGIN_CLASS_WITH_JSON(AltBatteryKcm, "kcm_altbattery.json")

#include "kcm.moc"
