# license-maven-plugin

为项目文件增加 `LICENSE` 头。

`LICENSE` 头如下所示，处于 `${project.basedir}/license.txt` 文件中：

``` txt
   Copyright ${license.git.copyrightYears} the original author or authors.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

```

`maven` 配置如下：

``` xml
<inceptionYear>2020</inceptionYear>

    <plugin>
        <groupId>com.mycila</groupId>
        <artifactId>license-maven-plugin</artifactId>
        <version>${license.version}</version>
        <executions>
            <execution>
                <id>first</id>
                <goals>
                    <goal>update-file-header</goal>
                </goals>
                <phase>process-sources</phase>
            </execution>
        </executions>
        <configuration>
            <quiet>true</quiet>
            <header>${project.basedir}/license.txt</header>
            <excludes>
                <exclude>**/*.properties</exclude>-->
                <exclude>*.sh</exclude>
                <exclude>*.yml</exclude>
                <exclude>.editorconfig</exclude>
                <exclude>.gitignore</exclude>
                <exclude>**/*.md</exclude>
                <exclude>**/*.xml</exclude>
                <exclude>**/*.ctrl</exclude>
                <exclude>**/*.dat</exclude>
                <exclude>**/*.lck</exclude>
                <exclude>**/*.log</exclude>
                <exclude>**/*maven-wrapper.properties</exclude>
                <exclude>.factorypath</exclude>
                <exclude>.gitattributes</exclude>
                <exclude>mvnw</exclude>
                <exclude>mvnw.cmd</exclude>
                <exclude>ICLA</exclude>
                <exclude>LICENSE</exclude>
                <exclude>KEYS</exclude>
                <exclude>NOTICE</exclude>
            </excludes>
            <strictCheck>true</strictCheck>
            <mapping>
                <java>SLASHSTAR_STYLE</java>
            </mapping>
        </configuration>
        <dependencies>
            <dependency>
                <groupId>com.mycila</groupId>
                <artifactId>license-maven-plugin-git</artifactId>
                <version>${license.version}</version>
            </dependency>
        </dependencies>
    </plugin>
```

其中`<mapping><java>SLASHSTAR_STYLE</java></mapping>`表示注释类型为`/* ... */`形式，查看[Supported comment types
](https://github.com/mycila/license-maven-plugin#supported-comment-types)获取更多信息。

生成的 `LICENSE` 头如下所示：

```java
/*
 *    Copyright 2020 the original author or authors.
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */
 ```

其中`${license.git.copyrightYears}`被替换为`inceptionYear`指定的`2020`年，此属性通过`license-maven-plugin-git`依赖引入。

- `license.git.copyrightLastYear` - the year of the last change of the present file as seen in git history
- `license.git.copyrightYears` - the combination of `project.inceptionYear` and `license.git.copyrightLastYear` delimited by a dash (-), or just p`roject.inceptionYear` if `project.inceptionYear` is eqal to `license.git.copyrightLastYear`

查看[license-maven-plugin-git
](https://github.com/mycila/license-maven-plugin/tree/master/license-maven-plugin-git)获取更多信息。



