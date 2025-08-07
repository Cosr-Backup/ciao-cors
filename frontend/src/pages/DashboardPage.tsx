import { useEffect, useState } from 'react';
import { Container, Grid, Paper, Title, Text, Group, RingProgress, SimpleGrid } from '@mantine/core';
import { IconArrowUp, IconArrowDown } from '@tabler/icons-react';
import { AreaChart } from '@mantine/charts';

interface Stats {
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  averageResponseTime: number;
  topDomains: Array<{ domain: string; count: number }>;
  hourlyStats: Array<{ hour: string; requests: number; errors: number }>;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      const response = await fetch('/api/admin/stats?range=day');
      const data = await response.json();
      setStats(data);
    } catch (error) {
      console.error('获取统计数据失败:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div>加载中...</div>;
  }

  if (!stats) {
    return <div>无法加载统计数据</div>;
  }

  const successRate = stats.totalRequests > 0 
    ? (stats.successfulRequests / stats.totalRequests) * 100 
    : 0;

  return (
    <Container fluid py="md">
      <Title order={2} mb="lg">仪表盘</Title>

      <Grid gutter="md">
        <Grid.Col span={{ base: 12, sm: 6, md: 3 }}>
          <Paper p="md" withBorder>
            <Group justify="space-between">
              <div>
                <Text size="sm" c="dimmed">总请求数</Text>
                <Title order={2}>{stats.totalRequests.toLocaleString()}</Title>
              </div>
              <IconArrowUp size={24} color="green" />
            </Group>
          </Paper>
        </Grid.Col>

        <Grid.Col span={{ base: 12, sm: 6, md: 3 }}>
          <Paper p="md" withBorder>
            <Group justify="space-between">
              <div>
                <Text size="sm" c="dimmed">成功请求</Text>
                <Title order={2}>{stats.successfulRequests.toLocaleString()}</Title>
              </div>
              <RingProgress
                size={60}
                thickness={6}
                sections={[{ value: successRate, color: 'teal' }]}
                label={<Text size="xs" ta="center">{Math.round(successRate)}%</Text>}
              />
            </Group>
          </Paper>
        </Grid.Col>

        <Grid.Col span={{ base: 12, sm: 6, md: 3 }}>
          <Paper p="md" withBorder>
            <Group justify="space-between">
              <div>
                <Text size="sm" c="dimmed">失败请求</Text>
                <Title order={2}>{stats.failedRequests.toLocaleString()}</Title>
              </div>
              <IconArrowDown size={24} color="red" />
            </Group>
          </Paper>
        </Grid.Col>

        <Grid.Col span={{ base: 12, sm: 6, md: 3 }}>
          <Paper p="md" withBorder>
            <div>
              <Text size="sm" c="dimmed">平均响应时间</Text>
              <Title order={2}>{Math.round(stats.averageResponseTime)}ms</Title>
            </div>
          </Paper>
        </Grid.Col>
      </Grid>

      <Grid gutter="md" mt="lg">
        <Grid.Col span={{ base: 12, md: 8 }}>
          <Paper p="md" withBorder>
            <Title order={3} mb="md">24小时请求趋势</Title>
            <AreaChart
              h={300}
              data={stats.hourlyStats}
              dataKey="hour"
              series={[
                { name: 'requests', color: 'blue.6', label: '请求数' },
                { name: 'errors', color: 'red.6', label: '错误数' }
              ]}
              curveType="linear"
            />
          </Paper>
        </Grid.Col>

        <Grid.Col span={{ base: 12, md: 4 }}>
          <Paper p="md" withBorder>
            <Title order={3} mb="md">热门域名</Title>
            <SimpleGrid cols={1} spacing="sm">
              {stats.topDomains.slice(0, 5).map((domain) => (
                <Group key={domain.domain} justify="space-between">
                  <Text size="sm" truncate>{domain.domain}</Text>
                  <Text size="sm" fw={500}>{domain.count}</Text>
                </Group>
              ))}
            </SimpleGrid>
          </Paper>
        </Grid.Col>
      </Grid>
    </Container>
  );
}