/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

// ALT Mobile: страница «Доступ по SSH». Состояние sshd читается из
// systemd по системной шине, включает и выключает его помощник KAuth
// org.altmobile.ssh (polkit спрашивает PIN-код), он же сообщает
// действующие настройки сервера.

#include <KAuth/Action>
#include <KAuth/ExecuteJob>
#include <KPluginFactory>
#include <KQuickConfigModule>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QNetworkInterface>
#include <QTimer>

static const QString systemd = QStringLiteral("org.freedesktop.systemd1");
static const QString unitName = QStringLiteral("sshd.service");

class AltSshKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)
    Q_PROPERTY(bool enabledAtBoot READ enabledAtBoot NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(QStringList addresses READ addresses NOTIFY stateChanged)
    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(int keyCount READ keyCount NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY settingsChanged)

public:
    AltSshKcm(QObject *parent, const KPluginMetaData &data)
        : KQuickConfigModule(parent, data)
    {
        setButtons(NoAdditionalButton);
        // systemd шлёт изменения юнитов только подписчикам: проще спрашивать
        m_timer.setInterval(3000);
        connect(&m_timer, &QTimer::timeout, this, &AltSshKcm::refresh);
        m_timer.start();
        refresh();
        readSettings();
    }

    bool active() const { return m_active; }
    bool enabledAtBoot() const { return m_enabledAtBoot; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QStringList addresses() const { return m_addresses; }
    QString userName() const { return qEnvironmentVariable("USER"); }
    int keyCount() const { return m_keyCount; }
    QVariantMap settings() const { return m_settings; }

    Q_INVOKABLE void setEnabled(bool value)
    {
        m_busy = true;
        m_error.clear();
        Q_EMIT stateChanged();
        KAuth::Action action(QStringLiteral("org.altmobile.ssh.set"));
        action.setHelperId(QStringLiteral("org.altmobile.ssh"));
        action.setArguments({{QStringLiteral("enabled"), value}});
        KAuth::ExecuteJob *job = action.execute();
        connect(job, &KJob::result, this, [this, job]() {
            m_busy = false;
            // Отказ в окне PIN-кода не ошибка: просто ничего не меняется
            if (job->error() && job->error() != KAuth::ActionReply::AuthorizationDeniedError
                && job->error() != KAuth::ActionReply::UserCancelledError) {
                m_error = job->errorString().isEmpty() ? job->errorText() : job->errorString();
            }
            refresh();
        });
        job->start();
    }

Q_SIGNALS:
    void stateChanged();
    void settingsChanged();

private Q_SLOTS:
    void refresh()
    {
        auto bus = QDBusConnection::systemBus();
        QDBusInterface manager(systemd, QStringLiteral("/org/freedesktop/systemd1"), QStringLiteral("org.freedesktop.systemd1.Manager"), bus);
        QDBusReply<QDBusObjectPath> unit = manager.call(QStringLiteral("LoadUnit"), unitName);
        if (unit.isValid()) {
            QDBusInterface props(systemd, unit.value().path(), QStringLiteral("org.freedesktop.systemd1.Unit"), bus);
            m_active = props.property("ActiveState").toString() == QLatin1String("active");
            m_enabledAtBoot = props.property("UnitFileState").toString() == QLatin1String("enabled");
        }

        m_addresses.clear();
        const auto ifaces = QNetworkInterface::allInterfaces();
        for (const QNetworkInterface &iface : ifaces) {
            if (!(iface.flags() & QNetworkInterface::IsUp) || (iface.flags() & QNetworkInterface::IsLoopBack)) {
                continue;
            }
            for (const QNetworkAddressEntry &entry : iface.addressEntries()) {
                const QHostAddress ip = entry.ip();
                // Адреса для соединения: IPv4 и глобальные IPv6
                if (ip.protocol() == QAbstractSocket::IPv4Protocol || (ip.protocol() == QAbstractSocket::IPv6Protocol && ip.isGlobal() && !ip.isLinkLocal())) {
                    m_addresses << ip.toString();
                }
            }
        }

        m_keyCount = 0;
        QFile keys(QDir::homePath() + QStringLiteral("/.ssh/authorized_keys"));
        if (keys.open(QIODevice::ReadOnly)) {
            const auto lines = keys.readAll().split('\n');
            for (const QByteArray &line : lines) {
                const QByteArray l = line.trimmed();
                if (!l.isEmpty() && !l.startsWith('#')) {
                    m_keyCount++;
                }
            }
        }
        Q_EMIT stateChanged();
    }

    void readSettings()
    {
        KAuth::Action action(QStringLiteral("org.altmobile.ssh.status"));
        action.setHelperId(QStringLiteral("org.altmobile.ssh"));
        KAuth::ExecuteJob *job = action.execute();
        connect(job, &KJob::result, this, [this, job]() {
            m_settings = job->error() ? QVariantMap() : job->data();
            Q_EMIT settingsChanged();
        });
        job->start();
    }

private:
    QTimer m_timer;
    bool m_active = false;
    bool m_enabledAtBoot = false;
    bool m_busy = false;
    QString m_error;
    QStringList m_addresses;
    int m_keyCount = 0;
    QVariantMap m_settings;
};

K_PLUGIN_CLASS_WITH_JSON(AltSshKcm, "kcm_altssh.json")

#include "kcm.moc"
