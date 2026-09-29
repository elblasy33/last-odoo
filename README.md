# 🚀 Odoo Suite (v16 — v20) Multi-Instance Installer (AI-Ready)
### Powered by [elblasy.app](https://elblasy.app) — Modern Cloud & DevOps Solutions

[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-orange.svg?style=for-the-badge&logo=ubuntu)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-Engine%20v24+-blue.svg?style=for-the-badge&logo=docker)](https://www.docker.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17%20(pgvector)-336791.svg?style=for-the-badge&logo=postgresql)](https://github.com/pgvector/pgvector)
[![Odoo](https://img.shields.io/badge/Odoo-v16%20|%20v17%20|%20v18%20|%20v19%20|%20v20-714B67.svg?style=for-the-badge&logo=odoo)](https://www.odoo.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

---

## 🌟 نظرة عامة | Overview

اسكريبت تثبيت احترافي فائق السرعة لنشر وإدارة نسخ **Odoo** متعددة على نفس السيرفر بنظام **Multi-Tenancy** كامل وبدون أي تعارض في البورتات أو الملفات.

يدعم الاسكريبت اختيار وتثبيت أي إصدار من **Odoo من الإصدار 16 وحتى 20** تفاعلياً، ومجهز بدعم كامل لتقنيات الذكاء الاصطناعي (مثل **AI Agents** وتقنية **RAG - Retrieval-Augmented Generation**) عبر دمج صورة **`pgvector/pgvector:pg17`** (قاعدة بيانات **PostgreSQL 17** المدمج معها امتداد الـ Vectors لحفظ واسترجاع المتجهات بكفاءة فائقة على قاعدة البيانات وقالب `template1`).

---

## ⚡ التثبيت السريع بسطر واحد | One-Line Fast Install

يمكنك تشغيل الاسكريبت مباشرة على أي سيرفر Ubuntu أو Debian عبر الأمر التالي:

```bash
curl -fsSL https://raw.githubusercontent.com/elblasy33/last-odoo/main/install.sh | sudo bash
```

أو عبر استنساخ المستودع (Clone):
```bash
git clone https://github.com/elblasy33/last-odoo.git
cd last-odoo
sudo bash install.sh
```

---

## ✨ المميزات الجوهرية والتريكات الذكية

### 1. 🎛️ قائمة اختيار إصدار Odoo من 16 إلى 20 (Interactive Version Selector)
يتيح لك الاسكريبت اختيار الإصدار المناسب لمشروعك عبر قائمة تفاعلية مرنة:
* **Odoo 20**: أحدث إصدار مدعوم بميزات الذكاء الاصطناعي و RAG وحفظ المتجهات في PostgreSQL 17.
* **Odoo 19**: الإصدار الحديث للشركات والمؤسسات.
* **Odoo 18 (LTS)**: الإصدار المستقر طويل الدعم.
* **Odoo 17 (LTS)**: الإصدار المستقر طويل الدعم.
* **Odoo 16 (LTS)**: الإصدار المستقر الكلاسيكي.
* **Custom Docker Image**: إمكانية إدخال أي صورة مخصصة أو مستودع خاص بك.

### 2. 🔁 تشغيل نسخ متعددة دون أي تعارض (Multi-Instance Isolated Tenancy)
* عند تشغيل الاسكريبت لأول مرة، ينشئ نسختك الأولى (مثلاً `odoo-app-1`).
* **عند تشغيل الاسكريبت مرة ثانية أو ثالثة على نفس السيرفر**:
  * يكتشف الاسكريبت النسخ الحالية تلقائياً ويعرضها لك.
  * يطلب منك تحديد اسم للنسخة الجديدة (أو يولد اسماً افتراضياً مثل `odoo-app-2`).
  * يتم عزل كل نسخة تماماً داخل مسار مخصص في `/opt/elblasy-odoo/instances/<اسم-النسخة>/`.
  * شبكة Docker معزولة وحاويات مستقلة لكل نسخة (`odoo_<name>`, `db_<name>`).

### 2. 🎯 كاشف البورتات التلقائي (Smart Port Conflict Hunter)
* يفحص البورتات الافتراضية (`8069` للويب، `8072` للشات، و `5432` لقاعدة البيانات).
* إذا كان أي بورت محجوزاً بواسطة نسخة سابقة أو خدمة أخرى، يبحث الاسكريبت فوراً عن أقرب بورت شاغر (`8070`, `8073`, ...) ويربطه تلقائياً دون أي تدخل يدوي!

### 3. 🧠 دعم كامل لـ AI Agents و RAG (PostgreSQL 17 + pgvector)
* تم استبدال صورة البوستجرس التقليدية بصورة **`pgvector/pgvector:pg17`**.
* تفعيل تلقائي لامتداد المتجهات:
  ```sql
  CREATE EXTENSION IF NOT EXISTS vector;
  ```
* يتيح لموديولات الذكاء الاصطناعي في Odoo تخزين الـ Vector Embeddings والبحث الدلالي (Semantic Search) بسرعة فائقة.

### 4. 🚀 ضبط أداء السيرفر تلقائياً (Auto-Tuning)
* فحص حجم الرامات وعدد الأنوية (CPUs) في السيرفر وتوليف إعدادات الـ DB تلقائياً:
  * `shared_buffers`, `effective_cache_size`, `work_mem`, `maintenance_work_mem`
  * حساب عدد الـ Odoo Workers بدقة: `(CPU Cores * 2) + 1` وحساب حدود الذاكرة `limit_memory_hard`.

### 5. 🎨 واجهة تفاعلية ملونة وبانر لشركة `elblasy.app`
* تصميم ANSI ملون وتدرج ألوان TrueColor.
* مؤشرات تقدم حية (Spinners) لكل مرحلة تشرح بالتفصيل ما يحدث خلف الكواليس.
* ملخص نهائي أنيق ببطاقة تحتوي على كافة الروابط وكلمات السر.

---

## 📁 هيكل المجلدات في `/opt`

يتم تنظيم النظام بأسلوب Enterprise داخل مجلد `/opt/elblasy-odoo`:

```text
/opt/elblasy-odoo/
├── instances/
│   ├── odoo-app-1/
│   │   ├── etc/
│   │   │   └── odoo.conf             # إعدادات Odoo المخصصة للنسخة
│   │   ├── addons/                   # موديولاتك المخصصة وإضافات الذكاء الاصطناعي
│   │   ├── data/                     # Odoo Filestore والملفات الثابتة
│   │   ├── db_data/                  # بيانات قاعدة بيانات PostgreSQL 17 + pgvector
│   │   ├── backups/                  # النسخ الاحتياطية الخاصة بالنسخة
│   │   ├── init-db/                  # اسكريبتات تفعيل pgvector تلقائياً على postgres و template1
│   │   ├── docker-compose.yml        # تركيبة تشغيل الحاويات المعزولة
│   │   └── .env                      # متغيرات البيئة والبورتات وكلمات السر
│   └── odoo-app-2/                   # النسخة الثانية المعزولة
```

---

## 🛠️ أداة التحكم السريعة للمشرفين (`elblasy` CLI)

يثبت الاسكريبت أداة سطر أوامر عامة في النظام باسم `elblasy` (أو `elblasy-odoo`) تمكنك من إدارة النسخ بسهولة:

```bash
# عرض جميع النسخ المثبتة وحالتها والبورتات الخاصة بها
elblasy list

# عرض السجلات الحية لنسخة معينة
elblasy logs odoo-app-1

# إعادة تشغيل نسخة معينة
elblasy restart odoo-app-1

# إيقاف أو تشغيل نسخة
elblasy stop odoo-app-1
elblasy start odoo-app-1

# أخذ نسخة احتياطية فورية كاملة (قاعدة البيانات + المتجهات + الـ Filestore)
elblasy backup odoo-app-1

# عرض تفاصيل وكلمات سر النسخة
elblasy info odoo-app-1

# حذف نسخة معينة وحاوياتها بأمان
elblasy delete odoo-app-1
```

---

## 🔒 الأمان وكلمات المرور

* يقوم الاسكريبت بتوليد **Master Password** وكلمات سر PostgreSQL عشوائية قوية لكل نسخة باستخدام `openssl`.
* ملفات التكوين والبيئة تحظى بصلاحيات صارمة (`chmod 600` و `chmod 640`).
* بورت قاعدة البيانات لا يُعرض للعامة بشكل مكشوف بل يرتبط محلياً فقط للحماية.

---

## 🤝 الدعم والمساهمة

تم تطوير هذا الاسكريبت بكل فخر بواسطة فريق **[elblasy.app](https://elblasy.app)** لدعم مجتمع مطوري ورواد أعمال Odoo في الشرق الأوسط والعالم العربي.

* **الموقع الإلكتروني**: [https://elblasy.app](https://elblasy.app)
* **الدعم والاستفسارات**: [support@elblasy.app](mailto:support@elblasy.app)
* **الترخيص**: [MIT License](LICENSE)
