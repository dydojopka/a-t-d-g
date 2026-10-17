# a-t-d-g

3D-игра на Godot и GDScript с преобразованием изображения в ASCII.
Версия редактора, указанная в проекте: Godot 4.7 (Forward Plus).

## Получение проекта

Установите Git и Git LFS, затем выполните:

```powershell
git lfs install
git clone https://github.com/dydojopka/a-t-d-g.git
cd a-t-d-g
git lfs pull
```

Импортируйте `project.godot` в Godot. Редактор создаст кэш `.godot/` автоматически.

## Сохранение изменений

```powershell
git status
git add .
git diff --cached --stat
git commit -m "Describe the change"
git push
```

Перед началом работы на другом компьютере выполните `git pull --ff-only` в чистой рабочей папке.

## Git LFS и ресурсы

Правила находятся в `.gitattributes`. Бинарные модели (`.glb`, `.blend`, `.fbx`),
текстуры, звук, видео, шрифты и бинарные ресурсы Godot хранятся через LFS.
Используйте расширения файлов в нижнем регистре, как в правилах.
GDScript, шейдеры, `.tscn`, `.tres`, SVG, `.gltf`, `.obj` и `.mtl` остаются текстовыми файлами Git.
Для `.gltf` связанный бинарный `.bin` и текстуры отслеживаются через LFS.

При добавлении нового бинарного формата настройте его **до первого коммита**:

```powershell
git lfs track "*.newformat"
git add .gitattributes
```

Проверка правил и уже добавленных ресурсов:

```powershell
git check-attr filter diff merge text -- assets/model.glb
git lfs ls-files
git lfs status
```

Пустой вывод `git lfs ls-files` нормален, пока бинарные ресурсы не добавлены.
Обычный `git push` отправляет и Git-коммиты, и соответствующие LFS-объекты.
У GitHub LFS есть отдельные квоты хранения и скачивания:
[документация GitHub](https://docs.github.com/en/billing/concepts/product-billing/git-lfs).

## Что хранить в репозитории

- Исходники, ресурсы, `project.godot`, `.gitattributes` и `.gitignore`.
- Файлы `.import` рядом с ресурсами и `.uid` рядом со скриптами: они нужны для настроек импорта и стабильных ссылок.
- `export_presets.cfg`, если он появится; секреты храните отдельно.

Кэш `.godot/`, сгенерированные `.translation` и каталог `android/`, локальные секреты и сборки
из `build/`, `builds/`, `dist/`, `exports/` исключены через `.gitignore`.
Сохраняйте экспорт игры в одном из этих каталогов.
